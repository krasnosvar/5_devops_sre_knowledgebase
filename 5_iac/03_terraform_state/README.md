# 03. Terraform state

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — команды и шаблоны одним экраном.

## Зачем

State — единственная связь между кодом и реальными ресурсами. Потерянный,
испорченный или одновременно изменённый state — это пересозданная база
или «осиротевшие» ресурсы. Здесь — remote backend, блокировки, секреты
в state и ручные операции (`import`, `state mv/rm`, восстановление).

## Пререквизиты

- [01_terraform_core](../01_terraform_core/) — особенно упражнения 03
  (drift, import) и 04 (remote state в локальном S3).
- [02_terraform_modules](../02_terraform_modules/) — адреса ресурсов в
  модулях (`module.x.resource.y`).

> **Забегание вперёд.** Примеры темы используют AWS S3, который подробно
> разбирается в [7_compute_platforms/02_aws](../../7_compute_platforms/02_aws/)
> (обзор, IAM, S3). Для этой темы достаточно: учётные данные
> (`aws configure` или `AWS_PROFILE`), регион, понятие S3-бакета и
> версионирования. Реальный AWS не обязателен: то же самое отрабатывается
> на локальном S3 в
> [упражнении 04 темы 01](../01_terraform_core/03_exercises/README.md).
> Если всё же используете AWS — новые аккаунты с 15 июля 2025 получают
> кредитный Free plan вместо 12-месячного free tier
> ([условия](https://aws.amazon.com/free/)); удаляйте бакеты после
> экспериментов.

## Файлы

- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: S3 lock, state-команды, import/moved.
- [01_theory/terraform_state.md](./01_theory/terraform_state.md) — зачем
  state, S3 backend и `use_lockfile`, секреты, import/mv/rm.
- [02_examples/backend.tf](./02_examples/backend.tf) — production S3
  backend с `use_lockfile = true`.
- [02_examples/state_operations.md](./02_examples/state_operations.md) —
  справочник команд работы со state с предупреждениями (это не скрипт:
  команды меняют живой state).
- Без упражнений: практика remote state и import — в
  [01_terraform_core](../01_terraform_core/03_exercises/README.md)
  (упражнения 03-04), полноценный S3 backend требует реального облака.

## Как проходить

1. Прочитать теорию.
2. Разобрать `backend.tf` и сравнить с локальным вариантом из ответа к
   упражнению 04 темы 01 (чем отличаются `endpoints`, `skip_*`).
3. Пройти `state_operations.md` на учебной конфигурации из
   `01_terraform_core/02_examples` (не на рабочем state): `state list`,
   `state show`, `moved`, `import`.

## Когда двигаться дальше

- Можете объяснить, как работает `use_lockfile` и почему DynamoDB для
  блокировок больше не нужна.
- Можете объяснить разницу `state rm` и `destroy` и чем блоки `moved`,
  `import`, `removed` лучше CLI-аналогов.
- Знаете, как восстановить state из версии S3 и когда безопасно
  `force-unlock`.

Следующая тема: [04_opentofu](../04_opentofu/).
