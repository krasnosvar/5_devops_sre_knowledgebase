# Terraform State — шпаргалка

Подробности и объяснения — в
[terraform_state.md](./01_theory/terraform_state.md). ⚠️ — опасная команда
или частая ловушка. Перед любой ручной правкой стейта:
`terraform state pull > backup.tfstate`.

## S3 backend с блокировкой

```hcl
terraform {
  backend "s3" {
    bucket       = "my-tfstate-prod"
    key          = "services/myapp/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true # lock = объект <key>.tflock в том же бакете
  }
}
```

| Задача | Команда / значение |
| :--- | :--- |
| Lock в S3 (Terraform/OpenTofu 1.10+) | `use_lockfile = true` — условная запись `If-None-Match: *` |
| Старый способ | `dynamodb_table = "..."` — deprecated; при миграции можно включить оба |
| Бакет | versioning + SSE-KMS + запрет публичного доступа + узкие IAM-права |
| Backend на окружение без копипасты | `terraform init -backend-config=prod.s3.tfbackend` |
| Сменить backend и перенести стейт | `terraform init -migrate-state` |
| Сменить backend без переноса | `terraform init -reconfigure` |
| Ждать lock вместо мгновенной ошибки | `terraform plan -lock-timeout=5m` |
| Снять зависший lock ⚠️ | `terraform force-unlock <LOCK_ID>` — только убедившись, что процесса нет |

⚠️ В `backend` нельзя `var.*` (`Variables not allowed`) — только
`-backend-config` (в OpenTofu 1.8+ — early evaluation).

## Команды state

| Задача | Команда |
| :--- | :--- |
| Список ресурсов | `terraform state list` |
| Атрибуты ресурса | `terraform state show 'aws_instance.web["web1"]'` |
| Скачать стейт (бэкап) | `terraform state pull > backup.tfstate` |
| Загрузить стейт ⚠️ | `terraform state push backup.tfstate` |
| Переименовать / перенести в модуль ⚠️ | `terraform state mv aws_instance.web aws_instance.nginx` |
| Забыть ресурс (в облаке остаётся) ⚠️ | `terraform state rm aws_instance.web` |
| Сменить источник провайдера | `terraform state replace-provider hashicorp/aws registry.example.com/org/aws` |
| Пересоздать ресурс (вместо `taint`) | `terraform apply -replace='aws_instance.web'` |
| Импорт CLI (старый способ) | `terraform import aws_vpc.main vpc-123456` |
| Сгенерировать код для `import`-блоков | `terraform plan -generate-config-out=generated.tf` |
| Только обновить стейт по облаку | `terraform plan -refresh-only` → `terraform apply -refresh-only` |
| План без refresh (быстро, ⚠️ не видит дрейф) | `terraform plan -refresh=false` |
| Детект дрейфа в CI | `terraform plan -detailed-exitcode` → 0 нет изменений, 1 ошибка, 2 diff |
| Workspaces | `terraform workspace list` / `new dev` / `select dev` |

⚠️ Адреса с `[...]` берите в одинарные кавычки — иначе их съест shell.

## Декларативный рефакторинг (через plan и ревью)

```hcl
import {
  to = aws_vpc.main
  id = "vpc-123456"
}

moved {
  from = aws_instance.web
  to   = aws_instance.nginx
}

removed {
  from = aws_instance.legacy
  lifecycle {
    destroy = false # забыть, как state rm, но через plan
  }
}
```

| Блок | Версия Terraform | Аналог CLI |
| :--- | :--- | :--- |
| `import` | 1.5+ (`for_each` в import — 1.7+) | `terraform import` |
| `moved` | 1.1+ | `terraform state mv` |
| `removed` | 1.7+ | `terraform state rm` |

## Секреты в стейте

| Факт | Что делать |
| :--- | :--- |
| Стейт — plain-text JSON, `sensitive` скрывает только вывод | шифровать бакет, ограничить чтение |
| `aws_iam_access_key`, пароли RDS, TLS-ключи — в стейте | секреты из Vault/SSM; доступ к бакету только CI |
| Не писать в стейт вовсе | ephemeral-ресурсы (1.10+), write-only аргументы (1.11+) |
| Клиентское шифрование стейта | OpenTofu `encryption {}` (см. [04_opentofu](../04_opentofu/CHEATSHEET.md)) |
| ⚠️ `terraform.tfstate` в Git | никогда: `*.tfstate*` и `.terraform/` в `.gitignore` |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| `Error acquiring the state lock` | Lock Info: `Who`/`Created`; живой ли процесс/CI → `force-unlock` |
| `Resource already exists` на `apply` | ресурс создан руками — `import` |
| Переименовал ресурс → план `destroy`+`create` | `moved` или `state mv` |
| `plan` идёт 15 минут | монолитный стейт — дробить по слоям, `terraform_remote_state` |
| Ресурс удалили руками в консоли | `plan` покажет пересоздание; `-refresh-only`, чтобы принять |
| Стейт повреждён/откатить | версия объекта в S3 (versioning) → `state push` |

> Проверка: флаги `plan`/`apply`/`init`/`state`/`force-unlock` по `--help`
> Terraform 1.16.5; `import`/`moved`/`removed` (на `terraform_data`) и
> `backend "s3"` прошли `terraform validate`/`tofu validate`;
> `Variables not allowed` воспроизведено на `backend "local"`; не проверено:
> реальная работа с S3 (нет аккаунта).
