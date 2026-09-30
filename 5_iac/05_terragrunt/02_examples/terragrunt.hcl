# Корневой terragrunt.hcl — общий backend и провайдер для всей инфраструктуры
# Размещается в корне infrastructure/

locals {
  account_id  = get_aws_account_id()
  region      = "eu-central-1"
  environment = element(split("/", path_relative_to_include()), 0)
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "my-tfstate-${local.account_id}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.region
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region = "${local.region}"
      default_tags {
        tags = {
          Environment = "${local.environment}"
          ManagedBy   = "Terragrunt"
        }
      }
    }
  EOF
}

inputs = {
  aws_region  = local.region
  environment = local.environment
}
