# notifications-worker infra

# point-6-problem: This whole file is a near copy of svc-appointments/main.tf. Two copies drift apart over time.
# point-16-problem: No test or CI check looked at this code before it was deployed.

resource "aws_cloudwatch_log_group" "logs" {
  name              = "/ecs/notifications-worker"
  retention_in_days = 7

  # point-10-problem: Tag keys are env/service here but Environment/Service in appointments. Cost reports and alerts miss this service.
  tags = {
    env     = "stg"
    service = "notifications-worker"
  }
}

# point-15-problem: These resources already run in staging. A refactor must not delete and recreate them.
resource "aws_iam_role" "task_execution_role" {
  name = "notifications-worker-exec-role"

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
    env     = "stg"
    service = "notifications-worker"
  }
}

resource "aws_iam_role_policy_attachment" "task_execution_managed" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# point-3-problem: The task needs the SMTP secret, but no policy allows secretsmanager:GetSecretValue. Tasks cannot start.
# This extra policy only repeats log permissions the managed policy already gives.
resource "aws_iam_role_policy" "task_execution_extra" {
  name = "notifications-worker-extra"
  role = aws_iam_role.task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_role" "task_role" {
  name = "notifications-worker-task-role"

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
    env     = "stg"
    service = "notifications-worker"
  }
}

resource "aws_security_group" "service" {
  name        = "notifications-worker-service"
  description = "notifications-worker tasks"
  # point-7-problem: Shared IDs (VPC, ALB, cluster, subnets) are typed by hand. If core-infra changes, these go stale.
  vpc_id = "vpc-0a1b2c3d4e5f67890"

  ingress {
    description = "From shared ALB"
    # point-1-problem: Opens port 3000, but the app and target group use 8080. The ALB can never reach the app.
    from_port       = 3000
    to_port         = 3000
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
    env     = "stg"
    service = "notifications-worker"
  }
}

resource "aws_lb_target_group" "this" {
  name        = "notifications-worker"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = "vpc-0a1b2c3d4e5f67890"
  target_type = "ip"

  health_check {
    enabled = true
    path    = "/health"
    port    = "traffic-port"
    matcher = "200"
    # point-2-problem: Checks every 10s and marks unhealthy after 2 failures. With the 10s grace below, a JVM that needs 60 to 90s is killed first.
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    env     = "stg"
    service = "notifications-worker"
  }
}

resource "aws_lb_listener_rule" "this" {
  listener_arn = "arn:aws:elasticloadbalancing:eu-central-1:123456789012:listener/app/shared-alb/50dc6c495c0c9188/f2f7dc8efc522ab2"
  priority     = 120

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    path_pattern {
      values = ["/notifications*"]
    }
  }
}

resource "aws_ecs_task_definition" "this" {
  # point-12-problem: Names are hardcoded even though var.service_name exists. That variable is never used.
  family                   = "notifications-worker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  # point-13-problem: Nothing checks cpu and memory. A bad pair only fails inside AWS during a deploy.
  cpu                = "512"
  memory             = "2048"
  execution_role_arn = aws_iam_role.task_execution_role.arn
  task_role_arn      = aws_iam_role.task_role.arn

  container_definitions = jsonencode([
    {
      name      = "notifications-worker"
      image     = var.image
      essential = true

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "SERVER_PORT", value = "8080" },
        { name = "SPRING_PROFILES_ACTIVE", value = "staging" }
      ]

      secrets = [
        {
          name      = "SMTP_CREDENTIALS"
          valueFrom = "arn:aws:secretsmanager:eu-central-1:123456789012:secret:notifications/smtp-creds-Xy9Zw8"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group" = "/ecs/notifications-worker"
          # point-5-problem: Logs go to us-east-1, but the service and log group are in eu-central-1. The log group stays empty.
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# point-14-problem: No depends_on. ECS can try to start before the listener rule and secret policy exist.
resource "aws_ecs_service" "this" {
  name            = "notifications-worker"
  cluster         = "arn:aws:ecs:eu-central-1:123456789012:cluster/platform-shared"
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  # point-2-problem: Grace is only 10s. ECS acts on failed health checks long before the JVM is ready.
  health_check_grace_period_seconds = 10

  network_configuration {
    # point-4-problem: subnet-0bbb7777aaaa8888d is not one of core-infra's private subnets. It was typed by hand and is wrong.
    subnets          = ["subnet-0aaa1111bbbb2222c", "subnet-0bbb7777aaaa8888d", "subnet-0eee5555ffff6666a"]
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "notifications-worker"
    container_port   = 8080
  }

  # point-8-problem: No deployment circuit breaker. A failing deploy loops forever and never rolls back.

  tags = {
    env     = "stg"
    service = "notifications-worker"
  }
}

output "target_group_arn" {
  value = aws_lb_target_group.this.arn
}

output "service_name" {
  value = aws_ecs_service.this.name
}
