# Terraform Modules — шпаргалка

Подробности и объяснения — в
[terraform_modules.md](./01_theory/terraform_modules.md). ⚠️ — опасная
команда или частая ловушка.

## Структура модуля

| Файл | Что внутри |
| :--- | :--- |
| `main.tf` | ресурсы |
| `variables.tf` | входы: всегда `type` и `description`; без `default` — обязательный |
| `outputs.tf` | выходы: `module.<name>.<output>` в родителе |
| `versions.tf` | `required_version`, `required_providers` (без блока `provider`!) |
| `README.md` | генерируется `terraform-docs markdown . > README.md` |

## Источники (`source`)

| Источник | Пример | Версия |
| :--- | :--- | :--- |
| Локальный | `source = "./modules/vpc"` | вместе с кодом |
| Registry | `source = "terraform-aws-modules/vpc/aws"` | `version = "~> 5.0"` |
| Git по тегу | `source = "git::https://github.com/org/vpc.git?ref=v1.2.0"` | ⚠️ без `?ref=` — HEAD ветки по умолчанию |
| Git, подкаталог | `source = "git::https://github.com/org/infra.git//modules/vpc?ref=v1.2.0"` | `//` отделяет путь |
| Git по SSH | `source = "git::ssh://git@github.com/org/vpc.git?ref=v1.2.0"` | |
| Приватный registry | `source = "app.terraform.io/org/vpc/aws"` / `gitlab.example.com/group/vpc/aws` | `version = ...` |

| Constraint | Значит |
| :--- | :--- |
| `= 1.2.0` | ровно эта |
| `~> 1.2` | `>= 1.2, < 2.0` |
| `~> 1.2.0` | `>= 1.2.0, < 1.3.0` |
| `>= 1.2, < 2.0` | явный диапазон |

⚠️ `version` работает только для registry-источников; для Git — `?ref=`.

## Вызов модуля

```hcl
provider "aws" {
  region = "eu-central-1"
}

provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}

module "db" {
  source   = "./modules/db"
  for_each = toset(["orders", "users"])

  db_name   = each.key
  disk_size = 100

  providers = {
    aws = aws.use1
  }
}

output "db_endpoints" {
  value = { for k, m in module.db : k => m.db_endpoint }
}
```

| Задача | Как |
| :--- | :--- |
| Размножить модуль | `count` / `for_each` на блоке `module` (с 0.13) → `module.db["orders"]` |
| Условно создать ресурс в модуле | `count = var.create_db ? 1 : 0` |
| Передать провайдер с alias | `providers = { aws = aws.use1 }`; в модуле — `configuration_aliases` |
| Вернуть значение наверх | `output` в модуле → `module.db.db_endpoint` |
| Опциональный вход | `default = "t3.micro"` (или `null`) |
| Опциональное поле объекта | `type = object({ size = optional(number, 20) })` |
| Обязательная проверка входа | блок `validation` в `variable` |

## Команды

| Задача | Команда |
| :--- | :--- |
| Скачать модули | `terraform init` (или только модули: `terraform get`) |
| Подтянуть новую версию из Git/registry | `terraform init -upgrade` / `terraform get -update` |
| Список модулей | `terraform modules` |
| Где кэш | `.terraform/modules/` (+ `modules.json`) |
| Тесты модуля | `terraform test` (файлы `*.tftest.hcl`) |
| Документация | `terraform-docs markdown table . > README.md` |
| Перенести ресурс в модуль без пересоздания | блок `moved`: `from = aws_vpc.main`, `to = module.vpc.aws_vpc.this` (см. [03_terraform_state](../03_terraform_state/CHEATSHEET.md)) |

## Правила хорошего модуля

| Правило | Почему |
| :--- | :--- |
| Нет блока `provider` внутри | иначе нет multi-region, а удаление вызова ломает `destroy` |
| Строгие `type` на входах | ошибка на `validate`, а не глубоко в `apply` |
| Вложенность ≤ 1 уровня | иначе прокидывание переменных через все слои |
| Пинить версии | чужой коммит не должен сломать прод |
| Чужой модуль не патчится снаружи | только через его `variables`; иначе форк |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| Изменения модуля в Git не подхватываются | кэш `.terraform/modules`: `init -upgrade` / `get -update` |
| `Provider configuration not present` при удалении | `provider` был внутри модуля — вернуть временно, `destroy`, вынести наверх |
| `Module not installed` | не было `terraform init` после добавления `module` |
| Пересоздание всего модуля после рефакторинга | адреса сменились — `moved` |

> Проверка: вызов модуля с `for_each`/`output`, `optional()` и команды
> `init`/`get`/`modules`/`test` сверены с Terraform 1.16.5 (`validate` в
> scratch на `terraform_data`); не проверено: `terraform-docs` (не
> установлен), блоки `provider "aws"` (провайдер не скачивался).
