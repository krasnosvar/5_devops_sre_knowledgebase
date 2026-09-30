# Tier-1 пример: Terraform + Docker provider (не нужен cloud аккаунт)
# Запуск:
#   terraform init
#   terraform apply
#   curl http://localhost:8080
#   terraform destroy

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

variable "nginx_port" {
  description = "Host port for nginx"
  type        = number
  default     = 8080
}

variable "app_name" {
  description = "Application name (used for naming resources)"
  type        = string
  default     = "lab-app"
}

# Образ
resource "docker_image" "nginx" {
  name         = "nginx:alpine"
  keep_locally = true   # не удалять образ при terraform destroy
}

# Сеть
resource "docker_network" "app_net" {
  name = "${var.app_name}-network"
}

# nginx контейнер
resource "docker_container" "nginx" {
  name  = "${var.app_name}-nginx"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = var.nginx_port
  }

  networks_advanced {
    name = docker_network.app_net.name
  }

  # custom index.html
  upload {
    content = "<h1>Hello from Terraform + Docker!</h1><p>Container: ${var.app_name}</p>"
    file    = "/usr/share/nginx/html/index.html"
  }

  restart = "unless-stopped"

  labels {
    label = "managed-by"
    value = "terraform"
  }
}

# Outputs
output "nginx_url" {
  value       = "http://localhost:${var.nginx_port}"
  description = "URL to access nginx"
}

output "container_id" {
  value       = docker_container.nginx.id
  description = "Docker container ID"
}
