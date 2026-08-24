terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

resource "docker_image" "nginx" {
  name         = "nginx:${var.nginx_tag}"
  keep_locally = true
}

resource "docker_container" "this" {
  name  = var.name
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = var.port
  }

  upload {
    content = var.html_content
    file    = "/usr/share/nginx/html/index.html"
  }

  restart = "unless-stopped"

  labels {
    label = "managed-by"
    value = "terraform"
  }
  labels {
    label = "env"
    value = var.environment
  }
}
