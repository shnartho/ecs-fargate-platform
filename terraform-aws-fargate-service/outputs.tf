output "service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.this.name
}

output "target_group_arn" {
  description = "ALB target group ARN."
  value       = aws_lb_target_group.this.arn
}

output "security_group_id" {
  description = "Security group attached to the tasks."
  value       = aws_security_group.this.id
}

output "task_role_arn" {
  description = "IAM role assumed by the application."
  value       = aws_iam_role.task.arn
}

output "task_role_name" {
  description = "IAM role name assumed by the application, for attaching service-specific policies."
  value       = aws_iam_role.task.name
}

output "log_group_name" {
  description = "CloudWatch log group for the container."
  value       = aws_cloudwatch_log_group.this.name
}
