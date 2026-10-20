# IaC на масштабе организации — шпаргалка

Подробности и объяснения — в [iac_at_scale.md](./01_theory/iac_at_scale.md).
⚠️ — опасная команда или частая ловушка.

## Монорепо vs полирепо

| | Монорепо | Полирепо |
| :--- | :--- | :--- |
| История и рефакторинг | один PR на всех потребителей | N отдельных PR |
| Права CI | ⚠️ часто на весь репо | граница = репозиторий команды |
| Скорость `plan` | медленно без разбиения на stacks | быстро |
| Общие модули | рядом с кодом | версионировать и публиковать |
| Частый компромисс | монорепо для платформенных модулей | полирепо/отдельные stacks для окружений приложений |

## Модули как продукт

| Задача | Как |
| :--- | :--- |
| Зафиксировать версию из Git | `source = "git::https://git.example.com/modules.git//vpc?ref=v1.4.2"` |
| Версия из registry | `source = "app.terraform.io/acme/vpc/aws"` + `version = "~> 1.4"` |
| SemVer | patch — безопасно, minor — новые опциональные входы, major — breaking |
| Тесты модуля | `terraform test` (файлы `*.tftest.hcl`), Terratest |
| Обновить модули после смены `ref` | `terraform init -upgrade` |

## Разделение state

| Подход | Блокировки | Blast radius |
| :--- | :--- | :--- |
| Один state на много команд | ⚠️ `apply` одной блокирует всех | всё сразу |
| State на team/env/region | независимые | одна зона владения |
| Мост между слоями | `data "terraform_remote_state"` или data sources облака | публичный интерфейс — outputs |
| DRY backend/provider | Terragrunt `remote_state` + `generate`, `terragrunt run --all plan` | — |

```hcl
terraform {
  backend "s3" {
    bucket       = "acme-tfstate"
    key          = "team-payments/prod/eu-central-1/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true # S3-native locking, DynamoDB больше не нужен
    encrypt      = true
  }
}
```

## Policy as Code

| Инструмент | Где | Что проверяет |
| :--- | :--- | :--- |
| Sentinel | HCP Terraform / Enterprise | план до `apply` |
| OPA / conftest | любой CI | JSON плана |
| Checkov / Trivy (`trivy config`) | любой CI | статический HCL |

```bash
terraform plan -out tfplan
terraform show -json tfplan > tfplan.json
conftest test tfplan.json --policy policy/
```

| Типовое правило | Пример |
| :--- | :--- |
| Запрет публичных бакетов | `aws_s3_bucket_public_access_block` обязателен |
| Обязательные теги | `owner`, `cost-center` |
| Разрешённые регионы | только `eu-*` |

## Дрифт-детект

| Задача | Как |
| :--- | :--- |
| Проверка дрифта в CI по расписанию | `terraform plan -detailed-exitcode -lock=false` |
| Код выхода | `0` — нет изменений, `1` — ошибка, `2` — есть дрифт/изменения |
| Только обновить state без изменений | `terraform plan -refresh-only` |
| Принять внешнее изменение в state | `terraform apply -refresh-only` (после ревью) |
| По всем stacks Terragrunt | `terragrunt run --all plan` |
| Реакция | ⚠️ алерт/дашборд, не авто-`apply`: ручной фикс мог быть намеренным |

```bash
terraform plan -detailed-exitcode -lock=false -input=false
rc=$?
case $rc in
  0) echo "no drift" ;;
  2) echo "DRIFT detected" ;;
  *) echo "plan failed"; exit "$rc" ;;
esac
```

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| Команды ждут друг друга на `apply` | общий state → разделить по владению |
| Обновление модуля сломало всех | нет `ref`/`version` → пиннинг + SemVer |
| Security-ревью — узкое горлышко | Policy as Code в CI до `apply` |
| Дрифт находят случайно | плановый `plan -detailed-exitcode` по всем stacks |
| `plan` монорепо идёт полчаса | нет декомпозиции state на stacks |

> Проверка: `terraform` и `tofu` `plan -help` (`-detailed-exitcode`,
> `-refresh-only`, `-lock`), `init -upgrade`, backend-блок прогнан
> `terraform validate` в scratch, shell-фрагмент — `bash -n`; не
> проверено: `conftest`, Sentinel, `terragrunt run --all` на реальных
> stacks.
