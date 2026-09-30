output "container_id" {
  description = "Docker container ID"
  value       = docker_container.this.id
}

output "url" {
  description = "URL to access the container"
  value       = "http://localhost:${var.port}"
}
