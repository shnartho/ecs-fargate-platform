variable "service_name" {
  type    = string
  default = "appointments-api"
}

variable "image" {
  type    = string
  default = "123456789012.dkr.ecr.eu-central-1.amazonaws.com/appointments-api:1.14.2"
}

variable "desired_count" {
  type    = number
  default = 2
}
