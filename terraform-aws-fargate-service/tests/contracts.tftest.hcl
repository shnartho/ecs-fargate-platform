mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      name = "us-west-2"
    }
  }
}

variables {
  name                              = "contract-service"
  image                             = "example/service:1.0.0"
  container_port                    = 9090
  cpu                               = 512
  memory                            = 1024
  health_check_grace_period_seconds = 5
  vpc_id                            = "vpc-0123456789abcdef0"
  subnet_ids                        = ["subnet-0123456789abcdef0"]
  cluster_arn                       = "arn:aws:ecs:us-west-2:123456789012:cluster/test"
  alb_listener_arn                  = "arn:aws:elasticloadbalancing:us-west-2:123456789012:listener/app/test/0123456789abcdef/0123456789abcdef"
  alb_security_group_id             = "sg-0123456789abcdef0"
  path_patterns                     = ["/test*"]
  listener_priority                 = 100

  secrets = {
    DATABASE       = "arn:aws:secretsmanager:us-west-2:123456789012:secret:database-Ab1Cd2"
    DATABASE_ALIAS = "arn:aws:secretsmanager:us-west-2:123456789012:secret:database-Ab1Cd2"
    SMTP           = "arn:aws:secretsmanager:us-west-2:123456789012:secret:smtp-Xy9Zw8"
  }
}

run "service_contract" {
  command = plan

  assert {
    condition = (
      jsondecode(aws_ecs_task_definition.this.container_definitions)[0].portMappings[0].containerPort == var.container_port &&
      aws_lb_target_group.this.port == var.container_port &&
      aws_lb_target_group.this.health_check[0].port == "traffic-port" &&
      one(aws_ecs_service.this.load_balancer).container_port == var.container_port
    )
    error_message = "Container, target group and service must use the configured port. Health checks must use the traffic port."
  }

  assert {
    condition = (
      length(aws_security_group.this.ingress) == 1 &&
      one(aws_security_group.this.ingress).from_port == var.container_port &&
      one(aws_security_group.this.ingress).to_port == var.container_port &&
      one(aws_security_group.this.ingress).protocol == "tcp"
    )
    error_message = "Exactly one ingress rule must allow TCP on the configured port."
  }

  assert {
    condition     = one(aws_security_group.this.ingress).security_groups == toset([var.alb_security_group_id])
    error_message = "The shared ALB must be the only source security group."
  }

  assert {
    condition = (
      length(coalesce(one(aws_security_group.this.ingress).cidr_blocks, [])) == 0 &&
      length(coalesce(one(aws_security_group.this.ingress).ipv6_cidr_blocks, [])) == 0 &&
      !coalesce(one(aws_security_group.this.ingress).self, false)
    )
    error_message = "Ingress must not allow CIDR ranges or the task security group itself."
  }

  assert {
    condition = (
      length(aws_iam_role_policy.execution_secrets) == 1 &&
      length(jsondecode(aws_iam_role_policy.execution_secrets[0].policy).Statement) == 1
    )
    error_message = "Declared secrets must produce one policy with one statement."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role_policy.execution_secrets[0].policy).Statement[0].Effect == "Allow" &&
      toset(jsondecode(aws_iam_role_policy.execution_secrets[0].policy).Statement[0].Action) == toset(["secretsmanager:GetSecretValue"])
    )
    error_message = "The secret policy must allow only GetSecretValue."
  }

  assert {
    condition = (
      toset(jsondecode(aws_iam_role_policy.execution_secrets[0].policy).Statement[0].Resource) == toset(values(var.secrets)) &&
      length(jsondecode(aws_iam_role_policy.execution_secrets[0].policy).Statement[0].Resource) == length(distinct(values(var.secrets)))
    )
    error_message = "The secret policy must cover exactly the declared ARNs, with no duplicates or wildcards."
  }

  assert {
    condition     = tomap({ for secret in jsondecode(aws_ecs_task_definition.this.container_definitions)[0].secrets : secret.name => secret.valueFrom }) == var.secrets
    error_message = "Container secret names and ARNs must match the caller's map."
  }

  assert {
    condition = (
      jsondecode(aws_ecs_task_definition.this.container_definitions)[0].logConfiguration.logDriver == "awslogs" &&
      jsondecode(aws_ecs_task_definition.this.container_definitions)[0].logConfiguration.options["awslogs-region"] == "us-west-2" &&
      jsondecode(aws_ecs_task_definition.this.container_definitions)[0].logConfiguration.options["awslogs-group"] == aws_cloudwatch_log_group.this.name
    )
    error_message = "Logs must use the provider region and the module's log group."
  }

  assert {
    condition = (
      aws_ecs_service.this.deployment_circuit_breaker[0].enable &&
      aws_ecs_service.this.deployment_circuit_breaker[0].rollback
    )
    error_message = "The deployment circuit breaker and rollback must stay enabled."
  }

  assert {
    condition = (
      !aws_ecs_service.this.network_configuration[0].assign_public_ip &&
      aws_ecs_service.this.network_configuration[0].subnets == toset(var.subnet_ids)
    )
    error_message = "The service must use the supplied subnets without public IPs."
  }

  assert {
    condition     = aws_iam_role.execution.name == "contract-service-task-execution-role"
    error_message = "Default execution-role naming must remain stable."
  }

  assert {
    condition     = aws_ecs_service.this.health_check_grace_period_seconds == 5
    error_message = "Caller-selected grace must not be constrained by ALB thresholds."
  }
}

run "existing_role_without_secrets" {
  command = plan

  variables {
    execution_role_name               = "notifications-worker-exec-role"
    health_check_grace_period_seconds = 150
    secrets                           = {}
  }

  assert {
    condition     = aws_iam_role.execution.name == "notifications-worker-exec-role"
    error_message = "An existing execution-role name must be preserved during adoption."
  }

  assert {
    condition = (
      length(aws_iam_role_policy.execution_secrets) == 0 &&
      length(jsondecode(aws_ecs_task_definition.this.container_definitions)[0].secrets) == 0
    )
    error_message = "Services without secrets must not receive a secret-access policy."
  }

  assert {
    condition     = aws_ecs_service.this.health_check_grace_period_seconds == 150
    error_message = "The caller's startup allowance must pass through unchanged."
  }
}

run "invalid_cpu_memory_pair" {
  command = plan

  variables {
    cpu    = 512
    memory = 512
  }

  expect_failures = [aws_ecs_task_definition.this]
}

run "invalid_memory_increment" {
  command = plan

  variables {
    cpu    = 8192
    memory = 18432
  }

  expect_failures = [aws_ecs_task_definition.this]
}

run "valid_large_task" {
  command = plan

  variables {
    cpu    = 8192
    memory = 20480
  }
}

run "unsupported_secret_selector" {
  command = plan

  variables {
    secrets = {
      PASSWORD = "arn:aws:secretsmanager:us-west-2:123456789012:secret:database-Ab1Cd2:password::"
    }
  }

  expect_failures = [var.secrets]
}