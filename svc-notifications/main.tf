locals {
  container_port = 8080
}

module "service" {
  # Pinned to a git tag in production, e.g. git::https://github.com/<org>/terraform-aws-fargate-service.git?ref=v1.0.0
  source = "../terraform-aws-fargate-service"

  name           = var.service_name
  image          = var.image
  container_port = local.container_port
  cpu            = 512
  memory         = 2048
  desired_count  = var.desired_count

  execution_role_name = "${var.service_name}-exec-role"

  environment_variables = {
    SERVER_PORT            = tostring(local.container_port)
    SPRING_PROFILES_ACTIVE = var.environment
  }

  secrets = {
    SMTP_CREDENTIALS = "arn:aws:secretsmanager:eu-central-1:123456789012:secret:notifications/smtp-creds-Xy9Zw8"
  }

  vpc_id                = local.core_infra.vpc_id
  subnet_ids            = local.core_infra.private_subnet_ids
  cluster_arn           = local.core_infra.ecs_cluster_arn
  alb_listener_arn      = local.core_infra.alb_https_listener_arn
  alb_security_group_id = local.core_infra.alb_security_group_id

  path_patterns     = ["/notifications*"]
  listener_priority = 120

  # Reported JVM startup is 60-90s. Allow extra time for health checks.
  health_check_grace_period_seconds = 150

  log_retention_in_days = 7

  tags = {
    Environment = var.environment
  }
}
