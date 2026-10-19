output "target_group_arn" {
  value = module.service.target_group_arn
}

output "service_name" {
  value = module.service.service_name
}

output "task_role_name" {
  value = module.service.task_role_name
}
