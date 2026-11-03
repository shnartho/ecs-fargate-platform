# point-12-problem: Declared but never used. Every name in main.tf is hardcoded instead.
variable "service_name" {
  type    = string
  default = "notifications-worker"
}

variable "image" {
  type    = string
  default = "123456789012.dkr.ecr.eu-central-1.amazonaws.com/notifications-worker:0.9.1"
}

variable "desired_count" {
  type    = number
  default = 2
}
