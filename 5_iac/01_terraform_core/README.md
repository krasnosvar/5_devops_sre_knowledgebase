# 01. Terraform core

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — команды и шаблоны одним экраном.

## Зачем

Инфраструктура, созданная руками, не воспроизводится и не ревьюится.
Terraform описывает её кодом: `plan` показывает, что изменится, `apply`
приводит реальность к коду. Здесь — как Terraform строит граф
зависимостей, что такое state и drift, workspaces и remote state.

## Пререквизиты

- [1_linux_and_shell](../../1_linux_and_shell/) — shell, переменные
  окружения, `curl`.
- [3_containers](../../3_containers/) — Docker: все лабы темы создают
  контейнеры через Docker provider; достаточно `docker run`/`ps`/`rm`/
  `inspect`.
- Terraform 1.10+ (нужен для `use_lockfile` в упражнении 04).

> **Забегание вперёд.** Упражнение 04 использует AWS CLI и S3 backend;
> AWS подробно разбирается в
> [7_compute_platforms/02_aws](../../7_compute_platforms/02_aws/). Для
> этой темы достаточно: `aws --endpoint-url=... s3 mb/ls` и фиктивные
> `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` — S3 поднимается локально
> в Docker, AWS-аккаунт не нужен. Если AWS CLI ещё не освоен —
> упражнение 04 можно пропустить и вернуться к нему позже.

## Файлы

- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: команды, count/for_each, lifecycle.
- [01_theory/terraform_internals.md](./01_theory/terraform_internals.md) —
  DAG, count vs for_each, dynamic blocks, data sources, lifecycle.
- [02_examples/main.tf](./02_examples/main.tf) — nginx-контейнер, сеть и
  outputs через Docker provider (Tier 1).
- [03_exercises/README.md](./03_exercises/README.md) — 5 упражнений,
  🐳 Tier 1.
- [04_exercises_answers/terraform-answers.md](./04_exercises_answers/terraform-answers.md) —
  ответы; конфигурации в
  [ex02_variables/](./04_exercises_answers/ex02_variables/),
  [ex04_remote_state/](./04_exercises_answers/ex04_remote_state/),
  [ex05_workspaces/](./04_exercises_answers/ex05_workspaces/).

## Как проходить

1. Прочитать теорию.
2. Пройти пример: `terraform init`, `plan -out=tfplan`, `apply tfplan`,
   `curl`, `destroy`.
3. Сделать упражнения 01-05 по порядку (03 опирается на 01).
4. Сверить с ответами; после каждой лабы — `terraform destroy`.

## Когда двигаться дальше

- Можете объяснить, зачем `plan -out` и почему `apply` сохранённого
  плана не задаёт вопросов.
- Можете без подсказки найти drift, синхронизировать state
  (`apply -refresh-only`) и импортировать существующий объект.
- Можете объяснить, почему workspaces на одном хосте конфликтуют без
  `terraform.workspace` в именах.

Следующая тема: [02_terraform_modules](../02_terraform_modules/).
