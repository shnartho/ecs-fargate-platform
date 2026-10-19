terraform {
  required_version = ">= 1.5"
}

# In production this repo provisions the shared VPC, ALB and ECS cluster
# consumed by every service repo. For this exercise it is STUBBED: the values
# are static, but the outputs and the committed local state file are real.
# Service repos must consume them the same way they would in production.

locals {
  vpc_id                 = "vpc-0a1b2c3d4e5f67890"
  private_subnet_ids     = ["subnet-0aaa1111bbbb2222c", "subnet-0ccc3333dddd4444e", "subnet-0eee5555ffff6666a"]
  alb_security_group_id  = "sg-0123abcd4567ef890"
  alb_https_listener_arn = "arn:aws:elasticloadbalancing:eu-central-1:123456789012:listener/app/shared-alb/50dc6c495c0c9188/f2f7dc8efc522ab2"
  ecs_cluster_arn        = "arn:aws:ecs:eu-central-1:123456789012:cluster/platform-shared"
  ecs_cluster_name       = "platform-shared"
}
