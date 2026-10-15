# Ответы — Terraform Modules

Готовый модуль лежит в
[../02_examples/modules/nginx_container/](../02_examples/modules/nginx_container/),
корневая конфигурация — [../02_examples/main.tf](../02_examples/main.tf).
Отличие от текста упражнений: в примере переменная HTML называется
`html_content` (а не `content`), а `required_providers` модуля лежит в
его `main.tf` (а не в отдельном `versions.tf`). Ниже — вариант точно
по условию упражнений. Никаких `-auto-approve`: перед `apply` читаем
план, `destroy` подтверждаем `yes`.

## Упражнение 01 — Написать модуль

Структура рабочей директории:

```text
ex01/
├── main.tf
└── modules/
    └── nginx_container/
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── versions.tf
```

`modules/nginx_container/versions.tf`:

```hcl
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}
```

`modules/nginx_container/main.tf`:

```hcl
resource "docker_image" "nginx" {
  name         = "nginx:alpine"
  keep_locally = true
}

resource "docker_container" "this" {
  name  = "nginx-${var.name}"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = var.port
  }

  upload {
    content = var.content
    file    = "/usr/share/nginx/html/index.html"
  }
}
```

`modules/nginx_container/variables.tf`:

```hcl
variable "name" {
  description = "Суффикс имени контейнера"
  type        = string
}

variable "port" {
  description = "Порт на хосте"
  type        = number
}

variable "content" {
  description = "Содержимое index.html"
  type        = string
}
```

`modules/nginx_container/outputs.tf`:

```hcl
output "container_id" {
  value = docker_container.this.id
}

output "url" {
  value = "http://localhost:${var.port}"
}
```

`main.tf` (корень) — ровно два `module`-блока из условия упражнения
плюс `provider "docker" {}`. Модуль не содержит блока `provider`:
провайдер конфигурирует корневой модуль.

```bash
cd ex01/
terraform init
terraform plan -out=tfplan
terraform apply tfplan
curl http://localhost:8081   # dev
curl http://localhost:8082   # staging
terraform destroy
```

Ожидаемый вывод (примерно так):

```text
Initializing modules...
- nginx_dev in modules/nginx_container
- nginx_staging in modules/nginx_container
...
Plan: 4 to add, 0 to change, 0 to destroy.
...
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.
<h1>Dev environment</h1>
<h1>Staging environment</h1>
...
Destroy complete! Resources: 4 destroyed.
```

Почему так: каждый вызов модуля — отдельный экземпляр со своими
ресурсами (`module.nginx_dev.docker_container.this` и т. д.), поэтому
ресурсов 4: образ и контейнер на каждый вызов. Новый модуль требует
`terraform init` — без него `plan` ответит `Module not installed`.

## Упражнение 02 — for_each с модулями

Заменить два `module`-блока в корневом `main.tf` на:

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

  name    = each.key
  port    = each.value.port
  content = each.value.content
}

output "urls" {
  value = { for k, v in module.nginx : k => v.url }
}
```

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
terraform output urls
docker ps --filter name=nginx- --format '{{.Names}} {{.Ports}}'
terraform destroy
```

Ожидаемый вывод (примерно так):

```text
Plan: 6 to add, 0 to change, 0 to destroy.
...
{
  "dev" = "http://localhost:8081"
  "prod" = "http://localhost:8083"
  "staging" = "http://localhost:8082"
}
nginx-prod 0.0.0.0:8083->80/tcp
nginx-staging 0.0.0.0:8082->80/tcp
nginx-dev 0.0.0.0:8081->80/tcp
```

Почему так: адреса становятся `module.nginx["dev"]` и т. д. Если
переходить с упражнения 01 на уже применённой инфраструктуре, план
предложит пересоздать всё (адреса поменялись). Чтобы этого избежать,
нужны блоки `moved { from = module.nginx_dev  to = module.nginx["dev"] }`
(или `terraform state mv`).

## Упражнение 03 — validation в variables

В `modules/nginx_container/variables.tf`:

```hcl
variable "name" {
  type = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.name))
    error_message = "Name may contain only letters, digits and hyphens."
  }
}

variable "port" {
  type = number
  validation {
    condition     = var.port >= 1024 && var.port <= 65535
    error_message = "Port must be between 1024 and 65535."
  }
}
```

Проверка. Важно: у корневого модуля нет переменных `port`/`name`, так
что `terraform plan -var="port=80"` проверяет не валидацию, а упадёт с
`Value for undeclared variable` — это ложная «проверка». Валидация
модуля срабатывает на значениях, переданных в `module`-блок. Временно
поменять в `local.environments` порт `dev` на `80`:

```bash
terraform plan
```

```text
Error: Invalid value for variable

  on main.tf line ..., in module "nginx":
  ...
Port must be between 1024 and 65535.
```

Затем вернуть порт `8081`, поменять ключ `dev` на `"dev env!"` (имя
`nginx-dev env!`) и снова `terraform plan`:

```text
Error: Invalid value for variable
...
Name may contain only letters, digits and hyphens.
```

Вернуть ключ `dev` и убедиться, что всё проходит:

```bash
terraform validate
terraform plan
```

```text
Success! The configuration is valid.
...
Plan: 6 to add, 0 to change, 0 to destroy.
```

Почему так: `validation` проверяет значение входной переменной того
модуля, где она объявлена, и останавливает `plan` до каких-либо
изменений. Проверять нужно по коду выхода и тексту ошибки, а не
`grep ... || echo "сработала"` — такая конструкция «проходит» при
любой ошибке, включая опечатку в имени переменной.
