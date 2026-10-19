# appointments-api infrastructure

resource "aws_cloudwatch_log_group" "logs" {
  name              = "/ecs/appointments-api"
  retention_in_days = 30

  tags = {
    Environment = "staging"
    Service     = "appointments-api"
  }
}

resource "aws_iam_role" "task_execution_role" {
  name = "appointments-api-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = "staging"
    Service     = "appointments-api"
  }
}

resource "aws_iam_role_policy_attachment" "task_execution_managed" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "task_execution_secrets" {
  name = "appointments-api-secrets"
  role = aws_iam_role.task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = ["arn:aws:secretsmanager:eu-central-1:123456789012:secret:appointments/db-creds-Ab1Cd2"]
      }
    ]
  })
}

resource "aws_iam_role" "task_role" {
  name = "appointments-api-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = "staging"
    Service     = "appointments-api"
  }
}

resource "aws_security_group" "service" {
  name        = "appointments-api-service"
  description = "appointments-api tasks"
  vpc_id      = "vpc-0a1b2c3d4e5f67890"

  ingress {
    description     = "From shared ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = ["sg-0123abcd4567ef890"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = "staging"
    Service     = "appointments-api"
  }
}

resource "aws_lb_target_group" "this" {
  name        = "appointments-api"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = "vpc-0a1b2c3d4e5f67890"
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Environment = "staging"
    Service     = "appointments-api"
  }
}

resource "aws_lb_listener_rule" "this" {
  listener_arn = "arn:aws:elasticloadbalancing:eu-central-1:123456789012:listener/app/shared-alb/50dc6c495c0c9188/f2f7dc8efc522ab2"
  priority     = 110

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    path_pattern {
      values = ["/appointments*"]
    }
  }
}

resource "aws_ecs_task_definition" "this" {
  family                   = "appointments-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  task_role_arn            = aws_iam_role.task_role.arn

  container_definitions = jsonencode([
    {
      name      = "appointments-api"
      image     = var.image
      essential = true

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "PORT", value = "8080" },
        { name = "NODE_ENV", value = "staging" }
      ]

      secrets = [
        {
          name      = "DB_CREDENTIALS"
          valueFrom = "arn:aws:secretsmanager:eu-central-1:123456789012:secret:appointments/db-creds-Ab1Cd2"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/appointments-api"
          "awslogs-region"        = "eu-central-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "this" {
  name                              = "appointments-api"
  cluster                           = "arn:aws:ecs:eu-central-1:123456789012:cluster/platform-shared"
  task_definition                   = aws_ecs_task_definition.this.arn
  desired_count                     = var.desired_count
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 60

  network_configuration {
    subnets          = ["subnet-0aaa1111bbbb2222c", "subnet-0ccc3333dddd4444e", "subnet-0eee5555ffff6666a"]
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "appointments-api"
    container_port   = 8080
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  tags = {
    Environment = "staging"
    Service     = "appointments-api"
  }
}

output "target_group_arn" {
  value = aws_lb_target_group.this.arn
}

output "service_name" {
  value = aws_ecs_service.this.name
}
