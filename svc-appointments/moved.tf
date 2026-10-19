moved {
  from = aws_cloudwatch_log_group.logs
  to   = module.service.aws_cloudwatch_log_group.this
}

moved {
  from = aws_iam_role.task_execution_role
  to   = module.service.aws_iam_role.execution
}

moved {
  from = aws_iam_role_policy_attachment.task_execution_managed
  to   = module.service.aws_iam_role_policy_attachment.execution_managed
}

moved {
  from = aws_iam_role_policy.task_execution_secrets
  to   = module.service.aws_iam_role_policy.execution_secrets[0]
}

moved {
  from = aws_iam_role.task_role
  to   = module.service.aws_iam_role.task
}

moved {
  from = aws_security_group.service
  to   = module.service.aws_security_group.this
}

moved {
  from = aws_lb_target_group.this
  to   = module.service.aws_lb_target_group.this
}

moved {
  from = aws_lb_listener_rule.this
  to   = module.service.aws_lb_listener_rule.this
}

moved {
  from = aws_ecs_task_definition.this
  to   = module.service.aws_ecs_task_definition.this
}

moved {
  from = aws_ecs_service.this
  to   = module.service.aws_ecs_service.this
}
