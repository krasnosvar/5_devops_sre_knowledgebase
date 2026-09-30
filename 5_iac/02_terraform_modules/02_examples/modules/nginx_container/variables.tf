variable "name" {
  description = "Container name"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name))
    error_message = "Name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "port" {
  description = "Host port (1024-65535)"
  type        = number
  validation {
    condition     = var.port >= 1024 && var.port <= 65535
    error_message = "Port must be between 1024 and 65535."
  }
}

variable "environment" {
  description = "Environment label (dev/staging/prod)"
  type        = string
  default     = "dev"
}

variable "nginx_tag" {
  description = "Nginx Docker image tag"
  type        = string
  default     = "alpine"
}

variable "html_content" {
  description = "HTML content for index.html"
  type        = string
  default     = "<h1>Hello from Terraform!</h1>"
}
