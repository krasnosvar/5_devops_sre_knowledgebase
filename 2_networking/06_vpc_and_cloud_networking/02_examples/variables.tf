variable "region" {
  description = "AWS регион"
  type        = string
  default     = "eu-central-1"
}

variable "blocked_cidr" {
  description = "CIDR, который NACL явно блокирует (демонстрация Deny, которого нет в Security Group)"
  type        = string
  default     = "198.51.100.0/24"
}
