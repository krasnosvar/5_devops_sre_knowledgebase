# Ответ к упражнению 05: один код, два workspace (dev/prod).
# Количество реплик и порты выбираются по terraform.workspace.
# В workspace "default" конфигурация намеренно падает: окружение
# должно быть выбрано явно.

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

locals {
  settings = {
    dev  = { replicas = 1, base_port = 8100 }
    prod = { replicas = 3, base_port = 8200 }
  }

  # Нет ключа для текущего workspace -> ошибка на plan (fail fast)
  env = local.settings[terraform.workspace]
}

resource "docker_image" "nginx" {
  name         = "nginx:alpine"
  keep_locally = true
}

# Имена сети и контейнеров содержат workspace, иначе dev и prod
# конфликтуют: это разные state, но один и тот же Docker daemon.
resource "docker_network" "net" {
  name = "lab-${terraform.workspace}-network"
}

resource "docker_container" "nginx" {
  count = local.env.replicas

  name  = "lab-${terraform.workspace}-nginx-${count.index}"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = local.env.base_port + count.index
  }

  networks_advanced {
    name = docker_network.net.name
  }
}

output "urls" {
  value = [
    for c in docker_container.nginx :
    "http://localhost:${c.ports[0].external}"
  ]
}
