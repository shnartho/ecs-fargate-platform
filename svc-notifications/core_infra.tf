# Local backend for this exercise; in production this would be core-infra's S3 state, read-only.
data "terraform_remote_state" "core_infra" {
  backend = "local"

  config = {
    path = "${path.module}/../core-infra/terraform.tfstate"
  }
}

locals {
  core_infra = data.terraform_remote_state.core_infra.outputs
}
