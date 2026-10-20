# Terraform Core — шпаргалка

Подробности и объяснения — в
[terraform_internals.md](./01_theory/terraform_internals.md). ⚠️ — опасная
команда или частая ловушка. Всё то же работает с `tofu` вместо `terraform`.

## Рабочий цикл

| Задача | Команда |
| :--- | :--- |
| Скачать провайдеры/модули, настроить backend | `terraform init` |
| Обновить провайдеры/модули в рамках constraints | `terraform init -upgrade` |
| Отформатировать / проверить формат в CI | `terraform fmt -recursive` / `terraform fmt -check -recursive` |
| Проверить синтаксис и типы (без API) | `terraform validate` |
| План в файл | `terraform plan -out=tfplan` |
| Применить ровно этот план | `terraform apply tfplan` |
| Посмотреть сохранённый план | `terraform show tfplan` / `terraform show -json tfplan` |
| Переменные | `-var 'env=prod'`, `-var-file=prod.tfvars`, `TF_VAR_env=prod` |
| Ограничить план ресурсом ⚠️ (только аварийно) | `terraform plan -target=aws_instance.web` |
| Принудительно пересоздать | `terraform apply -replace='aws_instance.web'` |
| План удаления ⚠️ | `terraform plan -destroy -out=tfplan` |
| Удалить всё ⚠️ | `terraform destroy` |
| Поднять/снизить параллелизм (по умолчанию 10) | `terraform apply -parallelism=20` |
| Значения output | `terraform output` / `terraform output -json` / `-raw name` |
| Поэкспериментировать с выражениями | `terraform console` |
| Граф зависимостей | `terraform graph \| dot -Tsvg > graph.svg` |
| Lock-файл под несколько платформ | `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64` |
| Подробные логи | `TF_LOG=DEBUG terraform plan` |

⚠️ В CI — `plan -out` → ревью → `apply tfplan`; без `-auto-approve` на
непроверенном плане.

## Порядок загрузки переменных (последний побеждает)

| # | Источник |
| :--- | :--- |
| 1 | `default` в `variable` |
| 2 | `TF_VAR_<name>` |
| 3 | `terraform.tfvars`, `terraform.tfvars.json` |
| 4 | `*.auto.tfvars` (по алфавиту) |
| 5 | `-var` / `-var-file` в порядке указания |

## count vs for_each

| | `count` | `for_each` |
| :--- | :--- | :--- |
| Адрес | `aws_instance.web[0]` | `aws_instance.web["web1"]` |
| Вход | число | `map` или `set(string)` |
| Удаление из середины | ⚠️ сдвиг индексов → пересоздание хвоста | трогает только удалённый ключ |
| Когда | условное создание `count = var.x ? 1 : 0` | всё остальное |
| Вместе | ⚠️ нельзя в одном блоке | |

## Синтаксис-шпаргалка

```hcl
variable "env" {
  type        = string
  description = "Окружение"
  validation {
    condition     = contains(["dev", "stage", "prod"], var.env)
    error_message = "env: dev, stage или prod."
  }
}

locals {
  tags = { env = var.env, managed_by = "terraform" }
}

resource "aws_instance" "web" {
  for_each      = toset(["web1", "web2"])
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  tags          = merge(local.tags, { Name = each.key })

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = false
    ignore_changes        = [tags["LastPatched"]]
  }
}

resource "aws_security_group" "app" {
  name = "app-${var.env}"
  dynamic "ingress" {
    for_each = [80, 443]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

output "web_ids" {
  value = { for k, v in aws_instance.web : k => v.id }
}
```

| Конструкция | Пример |
| :--- | :--- |
| Явная зависимость | `depends_on = [aws_iam_role_policy.app]` |
| Условие | `var.create ? 1 : 0` |
| for-выражение (список / map) | `[for s in var.list : upper(s)]` / `{ for k, v in var.map : k => v.id }` |
| Splat | `aws_instance.web[*].id` (только для `count`) |
| Data source | `data "aws_ami" "ubuntu" { most_recent = true ... }` → `data.aws_ami.ubuntu.id` |
| Скрыть в выводе | `sensitive = true` у `variable`/`output` |

## Lifecycle

| Аргумент | Эффект | Когда |
| :--- | :--- | :--- |
| `create_before_destroy` | сначала новый, потом удалить старый | замена без даунтайма |
| `prevent_destroy` | план с удалением падает | БД, бакеты со стейтом |
| `ignore_changes = [attr]` | не откатывать дрейф атрибута | `desired_capacity` ASG, теги от внешних систем |
| `replace_triggered_by` | пересоздать при изменении другого ресурса | ВМ при смене launch-скрипта |
| `precondition` / `postcondition` | проверка до/после | контракты модулей |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| После удаления элемента пересоздаётся «хвост» | `count` по списку — перейти на `for_each` (+ `moved`) |
| Ошибка data source на `plan` | объект не существует; если аргументы computed — чтение уходит в `apply` |
| `Cycle:` | взаимные ссылки ресурсов, лишний `depends_on` |
| Каждый `plan` показывает diff | дрейф или нормализация API: `ignore_changes`, исправить код |
| `Variables not allowed` в `backend` | backend читается до переменных: `-backend-config` |
| `"1" == 1` даёт `false` | `==` не приводит типы: `tostring()`/`tonumber()` |
| Секрет из `TF_VAR_...` | всё равно попадает в state открытым текстом |

> Проверка: флаги сверены с `--help` (Terraform 1.16.5, OpenTofu 1.12.3);
> `variable`/`locals`/`for_each`/`count`/`lifecycle`/`output` прошли
> `terraform validate` и `tofu validate` на `terraform_data`; `"1" == 1` — в
> `terraform console`; не проверено: блоки `aws_*` и `dynamic` (провайдер AWS
> не скачивался).
