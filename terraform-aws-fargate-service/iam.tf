locals {
  ecs_tasks_assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      }
    ]
  })
}

# Used by the ECS agent: pull the image, read secrets, write logs.
resource "aws_iam_role" "execution" {
  name               = "${var.name}-task-execution-role"
  assume_role_policy = local.ecs_tasks_assume_role_policy
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "execution_secrets" {
  count = length(var.secrets) > 0 ? 1 : 0

  name = "${var.name}-secrets"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = distinct(values(var.secrets))
      }
    ]
  })
}

# Used by the application itself. Callers attach their own policies via the task_role_name output.
resource "aws_iam_role" "task" {
  name               = "${var.name}-task-role"
  assume_role_policy = local.ecs_tasks_assume_role_policy
  tags               = local.tags
}
