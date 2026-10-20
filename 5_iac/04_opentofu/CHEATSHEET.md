# OpenTofu — шпаргалка

Подробности и объяснения — в [opentofu.md](./01_theory/opentofu.md). ⚠️ —
опасная команда или частая ловушка. Команды и флаги Terraform из
[01_terraform_core](../01_terraform_core/CHEATSHEET.md) работают с `tofu`.

## Terraform vs OpenTofu

| | Terraform | OpenTofu |
| :--- | :--- | :--- |
| Лицензия | BSL (с 1.6, лето 2023) | MPL 2.0, Linux Foundation |
| Форк | — | от Terraform 1.5.x |
| Бинарник | `terraform` | `tofu` |
| Синтаксис | HCL, блок `terraform {}` | тот же, `terraform {}` не переименован |
| Реестр по умолчанию | `registry.terraform.io` | `registry.opentofu.org` |
| Шифрование стейта на клиенте | нет | `encryption {}` (1.7+) |
| `var`/`local` в `backend` и `module.source` | ⚠️ нельзя | можно (early evaluation, 1.8+) |
| Исключить ресурс из плана | — | `tofu plan -exclude=aws_instance.web` (1.9+) |
| Провайдеры/модули из OCI-реестра | — | 1.10+ (зеркала, air-gapped) |
| S3 lock без DynamoDB | `use_lockfile` (1.10+) | `use_lockfile` (1.10+) |

## Миграция с Terraform

| Шаг | Команда |
| :--- | :--- |
| 1. Бэкап стейта | `terraform state pull > pre-tofu.tfstate` |
| 2. Чистый план в Terraform | `terraform plan` → «No changes» |
| 3. Инициализация | `tofu init` (провайдеры перекачаются из `registry.opentofu.org`) |
| 4. Сравнить план | `tofu plan` → «No changes» |
| 5. Применить, чтобы обновить стейт | `tofu apply` |
| Lock-файл | `.terraform.lock.hcl` пересоздаётся: хэши провайдеров другого реестра |

⚠️ Безопасно в обе стороны только до фич OpenTofu 1.7+: после
`encryption {}` или early evaluation Terraform стейт/код не прочитает.

## State encryption

```hcl
variable "state_passphrase" {
  type      = string
  sensitive = true
}

terraform {
  encryption {
    key_provider "pbkdf2" "main" {
      passphrase = var.state_passphrase # >= 16 символов
    }
    method "aes_gcm" "main" {
      keys = key_provider.pbkdf2.main
    }
    state {
      method   = method.aes_gcm.main
      enforced = true # отказ писать незашифрованный стейт
    }
    plan {
      method = method.aes_gcm.main
    }
  }
}
```

| Задача | Как |
| :--- | :--- |
| Ключ из KMS | `key_provider "aws_kms"` / `"gcp_kms"` / `"openbao"` |
| Передать конфиг без правки кода | env `TF_ENCRYPTION` (HCL/JSON) |
| Включить на существующем стейте | `method "unencrypted" "migrate" {}` + `fallback { method = method.unencrypted.migrate }` → `tofu apply` → убрать fallback |
| Ротация ключа | новый `key_provider`, старый — в `fallback` |
| ⚠️ Потеря ключа | стейт не расшифровать никак — хранить ключ отдельно и резервно |

## Early evaluation (1.8+)

```hcl
variable "env" {
  type = string
}

terraform {
  backend "s3" {
    bucket       = "tfstate-${var.env}"
    key          = "app/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
  }
}
```

`tofu init -var env=prod` — переменная должна быть известна на `init`
(только `var`/`local`, без ресурсов и data sources).

## Реестр

| Факт | Значение |
| :--- | :--- |
| `hashicorp/aws` в `tofu` | `registry.opentofu.org/hashicorp/aws` |
| Устройство | метаданные в Git → статические JSON по Registry Protocol через CDN |
| Бинарники | GitHub Releases авторов, проверка по checksum и подписи |
| ⚠️ «Реестр OpenTofu построен на OCI» | неверно: OCI — опциональная установка из своих реестров (1.10+) |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| После перехода другие хэши в lock-файле | нормально: другой реестр; закоммитить новый `.terraform.lock.hcl` |
| `Variables not allowed` в `backend` | это Terraform, а не `tofu`, или переменная не задана на `init` |
| Стейт не читается после `encryption` | нет ключа/пароля, `enforced` без `fallback` при миграции |
| Terraform не открывает стейт после tofu | использованы фичи OpenTofu — откат только с расшифровкой |

> Проверка: OpenTofu 1.12.3 — `encryption` (pbkdf2 + aes_gcm), миграция
> через `fallback` на локальном стейте (`apply` → стейт зашифрован), лимит
> passphrase 16 символов, early evaluation в `backend` (`init` с backend
> `local`), `-exclude` по `--help`; не проверено: `aws_kms`/`gcp_kms`/
> `openbao`, `TF_ENCRYPTION` (по документации OpenTofu).
