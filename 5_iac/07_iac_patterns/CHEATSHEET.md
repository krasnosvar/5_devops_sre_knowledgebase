# Паттерны IaC — шпаргалка

Подробности и объяснения — в [iac_patterns.md](./01_theory/iac_patterns.md).
⚠️ — опасная команда или частая ловушка.

## Mutable vs immutable

| | Mutable (Terraform + Ansible) | Immutable (Packer + Terraform/ASG) |
| :--- | :--- | :--- |
| Обновление | патчим живую ВМ | собираем новый образ, заменяем ВМ |
| Откат | сложно, серверы-снежинки | деплой старого образа (AMI) |
| Скорость автоскейлинга | медленно: старт + прогон плейбука | секунды: образ готов |
| Зависимости в рантайме | apt-репозиторий, Galaxy, Git | только на этапе сборки |
| Когда | долгоживущие stateful-хосты, bare metal | stateless-сервисы, ASG, контейнеры |

| Задача | Команда |
| :--- | :--- |
| Инициализировать плагины Packer | `packer init .` |
| Проверить шаблон | `packer validate .` / `packer fmt -check .` |
| Собрать образ | `packer build -var 'version=1.4.0' .` |

## Слои стейта (blast radius)

| Слой | Пример | Меняется | Риск |
| :--- | :--- | :--- | :--- |
| `01-network` | VPC, subnets, TGW | редко | очень высокий |
| `02-data` | RDS, Redis, S3 с данными | редко | высокий, `prevent_destroy` |
| `03-apps` | EKS, ASG, LB | часто | ограничен слоем |

| Связь слоёв | Как |
| :--- | :--- |
| Чтение outputs другого слоя | `data "terraform_remote_state" "net" { backend = "s3" ... }` → `data.terraform_remote_state.net.outputs.vpc_id` |
| Без доступа к чужому стейту | публиковать ID в SSM Parameter Store → `data "aws_ssm_parameter"` |
| Оркестрация слоёв | Terragrunt `dependency` + `run --all` ([05_terragrunt](../05_terragrunt/CHEATSHEET.md)) |

## PR-driven flow

| Шаг | Что происходит |
| :--- | :--- |
| 1 | PR с изменением `.tf` |
| 2 | CI/Atlantis: `fmt -check`, `validate`, `plan -out`, план — комментарием в PR |
| 3 | Ревью плана: что **удаляется** и **пересоздаётся** |
| 4 | Approve → `apply` сохранённого плана (до или после merge — по политике) |
| 5 | Ключи облака — только у раннера (OIDC), у людей read-only |

| Atlantis (комментарий в PR) | Действие |
| :--- | :--- |
| `atlantis plan` / `atlantis plan -d infra/prod` | план всех / одного каталога |
| `atlantis apply` / `atlantis apply -p prod` | применить все / один проект |
| `atlantis unlock` | снять lock каталога с этого PR |

## Drift detection

```bash
#!/usr/bin/env bash
set -euo pipefail
# Ночной job: 0 — нет изменений, 1 — ошибка, 2 — дрейф
set +e
terraform plan -detailed-exitcode -input=false -lock=false -no-color > plan.txt
rc=$?
set -e
case "$rc" in
  0) echo "no drift" ;;
  2) echo "DRIFT detected"; exit 2 ;;  # CI шлёт алерт по коду 2
  *) echo "plan failed"; exit 1 ;;
esac
```

| Мера | Что даёт |
| :--- | :--- |
| Read-only консоль для людей | ClickOps невозможен |
| `plan -detailed-exitcode` по крону | обнаружение дрейфа |
| AWS Config | *обнаруживает* нарушения правил, может автоисправлять |
| IAM / SCP | *блокируют* ручные изменения на уровне API |

## Секреты

| Способ | Плюс | ⚠️ |
| :--- | :--- | :--- |
| `data "aws_ssm_parameter"` / Secrets Manager | секрет не в Git | значение оседает в стейте |
| Vault provider (динамические креды) | короткий TTL | в стейте тоже |
| ephemeral-ресурсы (TF 1.10+), write-only аргументы (1.11+) | не пишутся в стейт | нужна поддержка провайдера |
| OpenTofu `encryption {}` | стейт зашифрован на клиенте | потеря ключа = потеря стейта |
| `terraform.tfvars` в Git | — | ⚠️ никогда; утёк — ротировать, force push не спасает |

## Антипаттерны

| Антипаттерн | Почему плохо | Вместо |
| :--- | :--- | :--- |
| Монолитный стейт на 10 000 ресурсов | plan 30 мин, blast radius = вся компания | слои / стейт на сервис |
| `apply` с ноутбука | нет аудита, ключи у людей | PR-driven CI/Atlantis |
| Миграция БД через `provisioner "local-exec"` | упал → ресурс `tainted` → ⚠️ пересоздание БД | CI-job / Job в k8s |
| ClickOps | нет истории и ревью | всё через Git |
| Секрет в `.tf`/`.tfvars` | утечка навсегда | SSM/Vault + ротация |

## Terraform vs CloudFormation

| | Terraform / OpenTofu | CloudFormation |
| :--- | :--- | :--- |
| Где движок | клиент (CI-раннер) | сервис AWS |
| Стейт | свой (S3 и т.п.) | внутри AWS |
| Облака | любые провайдеры | только AWS |
| Откат при ошибке | нет | автоматический rollback стека |

> Проверка: drift-скрипт — `bash -n`, ветка с кодом 2 воспроизведена на
> `terraform_data` + local backend (Terraform 1.16.5); не проверено: Packer и
> Atlantis (не установлены, по документации), AWS Config/SCP.
