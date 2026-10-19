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
  memory         = 1024
  desired_count  = var.desired_count

  environment_variables = {
    PORT     = tostring(local.container_port)
    NODE_ENV = var.environment
  }

  secrets = {
    DB_CREDENTIALS = "arn:aws:secretsmanager:eu-central-1:123456789012:secret:appointments/db-creds-Ab1Cd2"
  }

  vpc_id                = local.core_infra.vpc_id
  subnet_ids            = local.core_infra.private_subnet_ids
  cluster_arn           = local.core_infra.ecs_cluster_arn
  alb_listener_arn      = local.core_infra.alb_https_listener_arn
  alb_security_group_id = local.core_infra.alb_security_group_id

  path_patterns                     = ["/appointments*"]
  listener_priority                 = 110
  health_check_grace_period_seconds = 60

  log_retention_in_days = 30

  tags = {
    Environment = var.environment
  }
}
