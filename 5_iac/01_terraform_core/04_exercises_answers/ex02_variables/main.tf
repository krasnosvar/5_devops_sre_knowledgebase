# Ответ к упражнению 02: параметризованный nginx-контейнер.
# Вход: image, port, container_name. Выход: container_id, url.

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

# Значений по умолчанию нет намеренно: всё передаётся явно
# (-var, terraform.tfvars или TF_VAR_*), иначе plan спросит/упадёт.
variable "image" {
  description = "Docker-образ, например nginx:alpine"
  type        = string
}

variable "port" {
  description = "Порт на хосте"
  type        = number
}

variable "container_name" {
  description = "Имя контейнера"
  type        = string
}

resource "docker_image" "this" {
  name         = var.image
  keep_locally = true
}

resource "docker_container" "this" {
  name  = var.container_name
  image = docker_image.this.image_id

  ports {
    internal = 80
    external = var.port
  }
}

output "container_id" {
  description = "ID контейнера"
  value       = docker_container.this.id
}

output "url" {
  description = "URL контейнера"
  value       = "http://localhost:${var.port}"
}
