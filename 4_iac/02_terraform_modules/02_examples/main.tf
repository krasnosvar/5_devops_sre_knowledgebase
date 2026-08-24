# Использование модуля nginx_container
# Запуск: terraform init && terraform apply

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

# Простое использование модуля
module "nginx_dev" {
  source      = "./modules/nginx_container"
  name        = "nginx-dev"
  port        = 8081
  environment = "dev"
  html_content = "<h1>Dev Environment</h1>"
}

module "nginx_staging" {
  source      = "./modules/nginx_container"
  name        = "nginx-staging"
  port        = 8082
  environment = "staging"
  html_content = "<h1>Staging Environment</h1>"
}

# for_each — создать N окружений из map
locals {
  environments = {
    qa   = { port = 8083, content = "<h1>QA</h1>" }
    demo = { port = 8084, content = "<h1>Demo</h1>" }
  }
}

module "nginx_extra" {
  for_each    = local.environments
  source      = "./modules/nginx_container"
  name        = "nginx-${each.key}"
  port        = each.value.port
  html_content = each.value.content
  environment = each.key
}

output "urls" {
  value = {
    dev     = module.nginx_dev.url
    staging = module.nginx_staging.url
    extra   = { for k, v in module.nginx_extra : k => v.url }
  }
}
