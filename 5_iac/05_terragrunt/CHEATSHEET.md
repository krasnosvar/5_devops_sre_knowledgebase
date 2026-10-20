# Terragrunt — шпаргалка

Подробности и объяснения — в [terragrunt.md](./01_theory/terragrunt.md). ⚠️ —
опасная команда или частая ловушка. Команды — для Terragrunt 1.x
(CLI redesign: `run`, `--all`, `TG_*`); `run-all` и `--terragrunt-*` флаги
удалены.

## Команды

| Задача | Команда |
| :--- | :--- |
| План одного юнита | `terragrunt plan` (= `terragrunt run plan`) |
| План всего стека в каталоге | `terragrunt run --all plan` |
| Применить стек ⚠️ (сам добавляет `-auto-approve`) | `terragrunt run --all apply` |
| Применить стек с подтверждением | `terragrunt run --all --no-auto-approve apply` |
| Удалить стек ⚠️ (порядок DAG обратный) | `terragrunt run --all destroy` |
| Передать флаги tofu/terraform | `terragrunt run -- plan -out=tfplan` |
| Без вопросов (CI) | `--non-interactive` / `TG_NON_INTERACTIVE=true` |
| Параллелизм `--all` | `--parallelism 4` |
| Продолжать при ошибке зависимости | `--queue-ignore-errors` |
| Отфильтровать юниты | `--filter './prod/**'` (путь-glob) или `--filter 'vpc'` (имя) |
| Только изменённые в ветке | `--filter-affected` |
| Какой бинарник | `--tf-path terraform` / `TG_TF_PATH=terraform` (по умолчанию `tofu`) |
| Локальный исходник модуля вместо Git | `terragrunt plan --source ../../modules//vpc` |
| Сбросить кэш исходников | `--source-update` или удалить `.terragrunt-cache/` |
| Кэш провайдеров для стека | `--provider-cache` |
| Найти / перечислить юниты | `terragrunt find` / `terragrunt list --dag` |
| Граф зависимостей | `terragrunt dag graph \| dot -Tsvg > dag.svg` |
| Итоговый конфиг после include | `terragrunt render --json` |
| Форматировать / проверить HCL | `terragrunt hcl fmt` / `terragrunt hcl fmt --check` / `terragrunt hcl validate` |
| Создать бакет стейта заранее | `terragrunt backend bootstrap` (или `--backend-bootstrap`) |
| Outputs юнита | `terragrunt output -json` |

| Было (≤0.7x) | Стало (1.x) |
| :--- | :--- |
| `terragrunt run-all apply` | `terragrunt run --all apply` |
| `terragrunt graph-dependencies` | `terragrunt dag graph` |
| `terragrunt render-json` | `terragrunt render --json` |
| `terragrunt hclfmt` | `terragrunt hcl fmt` |
| `--terragrunt-non-interactive` | `--non-interactive` |
| `TERRAGRUNT_*` env | `TG_*` env |

## Раскладка

```text
live/
├── root.hcl                # remote_state, generate provider, общие inputs
└── prod/
    └── eu-west-1/
        ├── vpc/terragrunt.hcl
        └── eks/terragrunt.hcl   # dependency "vpc"
```

## Корневой `root.hcl`

```hcl
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket       = "my-tfstate-prod"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOT
    provider "aws" {
      region = "eu-west-1"
    }
  EOT
}
```

## Юнит с зависимостью

```hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "git::https://github.com/org/modules.git//eks?ref=v1.4.0"
}

dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    vpc_id = "vpc-mock"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  vpc_id = dependency.vpc.outputs.vpc_id
}
```

| Функция | Что даёт |
| :--- | :--- |
| `find_in_parent_folders("root.hcl")` | путь к корневому конфигу вверх по дереву |
| `path_relative_to_include()` | `prod/eu-west-1/vpc` — уникальный `key` стейта |
| `get_terragrunt_dir()` | каталог текущего юнита |
| `read_terragrunt_config(find_in_parent_folders("env.hcl"))` | общие `locals` окружения |
| `yamldecode(file(...))` | значения из YAML |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| `unknown command: "run-all"` | Terragrunt 1.x: `run --all` |
| `plan` на пустом окружении падает на `dependency` | нет outputs у зависимости — `mock_outputs` |
| Модуль из Git не обновился | `.terragrunt-cache/` — `--source-update` |
| Упал юнит в середине `run --all` | отката нет; починить и повторить — продолжит идемпотентно |
| Два запуска в одном юните | lock делает сам tofu/terraform (`use_lockfile`) |
| Диск забит | `.terragrunt-cache/` в каждом юните — чистить, `--provider-cache` |

> Проверка: Terragrunt 1.1.6 + OpenTofu 1.12.3 в scratch — стек `vpc`→`app`
> на backend `local`: `hcl fmt --check`, `hcl validate`, `find`, `list --dag`,
> `dag graph`, `run --all plan` (mock_outputs), `apply`, `render --json`,
> `destroy` в обратном порядке, `--filter`; флаги — по `run --help`; не
> проверено: backend `s3` и `backend bootstrap` (нет аккаунта AWS).
