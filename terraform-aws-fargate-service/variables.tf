# --- Service identity -------------------------------------------------------

variable "name" {
  description = "Service name. Used for the ECS service, container, target group, log group and IAM roles."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,30}[a-z0-9]$", var.name))
    error_message = "name must be 2-32 lowercase letters, digits or hyphens (ALB target group name limit)."
  }
}

variable "image" {
  description = "Container image URI, pinned to a tag or digest."
  type        = string
}

variable "container_port" {
  description = "Port the container listens on. Drives the port mapping, target group and security group rule."
  type        = number
  default     = 8080

  validation {
    condition     = var.container_port >= 1 && var.container_port <= 65535
    error_message = "container_port must be between 1 and 65535."
  }
}

variable "cpu" {
  description = "Fargate task CPU units."
  type        = number

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096, 8192, 16384], var.cpu)
    error_message = "cpu must be a valid Fargate value: 256, 512, 1024, 2048, 4096, 8192 or 16384."
  }
}

variable "memory" {
  description = "Fargate task memory in MiB. Must be a valid combination with cpu."
  type        = number

  validation {
    condition     = var.memory >= 512
    error_message = "memory must be at least 512 MiB."
  }
}

variable "desired_count" {
  description = "Number of tasks to run."
  type        = number
  default     = 2

  validation {
    condition     = var.desired_count >= 0
    error_message = "desired_count must not be negative."
  }
}

variable "environment_variables" {
  description = "Plain-text environment variables for the container. Do not put secrets here."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Container env var name => Secrets Manager secret ARN. The execution role is granted GetSecretValue on exactly these ARNs."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for arn in values(var.secrets) : can(regex("^arn:aws:secretsmanager:[a-z0-9-]+:[0-9]{12}:secret:.+$", arn))])
    error_message = "Every secrets value must be a full Secrets Manager secret ARN."
  }
}

# --- Shared platform (from core-infra outputs) -------------------------------

variable "vpc_id" {
  description = "VPC the service runs in."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the tasks."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one subnet is required."
  }
}

variable "cluster_arn" {
  description = "ECS cluster to run the service in."
  type        = string
}

variable "alb_listener_arn" {
  description = "Shared ALB listener to attach the routing rule to."
  type        = string
}

variable "alb_security_group_id" {
  description = "Security group of the shared ALB; the only source allowed to reach the tasks."
  type        = string
}

# --- Routing and health -----------------------------------------------------

variable "path_patterns" {
  description = "ALB path patterns routed to this service."
  type        = list(string)

  validation {
    condition     = length(var.path_patterns) >= 1 && length(var.path_patterns) <= 5
    error_message = "path_patterns must contain between 1 and 5 patterns (ALB condition limit)."
  }
}

variable "listener_priority" {
  description = "Listener rule priority. Must be unique on the shared listener."
  type        = number

  validation {
    condition     = var.listener_priority >= 1 && var.listener_priority <= 50000
    error_message = "listener_priority must be between 1 and 50000."
  }
}

variable "health_check" {
  description = "ALB target group health check. Defaults suit a service that answers GET /health with 200."
  type = object({
    path                = optional(string, "/health")
    matcher             = optional(string, "200")
    interval            = optional(number, 30)
    timeout             = optional(number, 5)
    healthy_threshold   = optional(number, 2)
    unhealthy_threshold = optional(number, 3)
  })
  default = {}

  validation {
    condition     = var.health_check.timeout < var.health_check.interval
    error_message = "health_check.timeout must be less than health_check.interval."
  }
}

variable "health_check_grace_period_seconds" {
  description = "Seconds ECS ignores failing ALB health checks after a task starts. Must exceed the app's worst-case startup time."
  type        = number

  validation {
    condition     = var.health_check_grace_period_seconds >= 0
    error_message = "health_check_grace_period_seconds must not be negative."
  }
}

# --- Operations -------------------------------------------------------------

variable "log_retention_in_days" {
  description = "CloudWatch log retention."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_in_days)
    error_message = "log_retention_in_days must be a value CloudWatch Logs supports."
  }
}

variable "tags" {
  description = "Tags applied to every resource. A Service tag is always added."
  type        = map(string)
  default     = {}
}
