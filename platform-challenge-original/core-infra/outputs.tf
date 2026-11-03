output "vpc_id" {
  value = local.vpc_id
}

output "private_subnet_ids" {
  value = local.private_subnet_ids
}

output "alb_security_group_id" {
  value = local.alb_security_group_id
}

output "alb_https_listener_arn" {
  value = local.alb_https_listener_arn
}

output "ecs_cluster_arn" {
  value = local.ecs_cluster_arn
}

output "ecs_cluster_name" {
  value = local.ecs_cluster_name
}
