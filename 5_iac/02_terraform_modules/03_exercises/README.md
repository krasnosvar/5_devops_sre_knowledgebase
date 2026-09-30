# Упражнения — Terraform Modules

Стенд: 🐳 Tier 1 — Docker provider / 🖥 Tier 2 — libvirt

## 01 — Написать модуль

**Задача:** Выделить из `4_iac/01_terraform_core/02_examples/main.tf` повторяющиеся части в модуль.

```
modules/
└── nginx_container/
    ├── main.tf       ← docker_image + docker_container
    ├── variables.tf  ← name, port, content
    ├── outputs.tf    ← container_id, url
    └── versions.tf   ← required_providers
```

```hcl
# Использование модуля
module "nginx_dev" {
  source  = "./modules/nginx_container"
  name    = "dev"
  port    = 8081
  content = "<h1>Dev environment</h1>"
}

module "nginx_staging" {
  source  = "./modules/nginx_container"
  name    = "staging"
  port    = 8082
  content = "<h1>Staging environment</h1>"
}
```

```bash
terraform init
terraform apply
curl http://localhost:8081   # dev
curl http://localhost:8082   # staging
```

## 02 — for_each с модулями

**Задача:** Переписать упражнение 01 используя `for_each` вместо двух отдельных module блоков.

```hcl
locals {
  environments = {
    dev     = { port = 8081, content = "<h1>Dev</h1>" }
    staging = { port = 8082, content = "<h1>Staging</h1>" }
    prod    = { port = 8083, content = "<h1>Prod</h1>" }
  }
}

module "nginx" {
  for_each = local.environments
  source   = "./modules/nginx_container"
  # TODO: передать значения из local.environments
}

# Output для каждого environment
output "urls" {
  value = { for k, v in module.nginx : k => v.url }
}
```

## 03 — validation в variables

**Задача:** Добавить `validation` блоки в `modules/nginx_container/variables.tf`:
- port должен быть в диапазоне 1024-65535
- name должен содержать только буквы, цифры и дефисы

```hcl
variable "port" {
  type = number
  validation {
    condition     = ???
    error_message = "Port must be between 1024 and 65535."
  }
}
```
