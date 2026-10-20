# 02. Terraform modules

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — команды и шаблоны одним экраном.

## Зачем

Копипаста одних и тех же ресурсов по окружениям множит ошибки. Модуль —
это «функция» Terraform: входные переменные, ресурсы, outputs. Здесь —
структура модуля, источники (локальные, Git, Registry), `for_each` по
модулям и `validation` входов.

## Пререквизиты

- [01_terraform_core](../01_terraform_core/) — variables, outputs, цикл
  `init → plan → apply → destroy`, count vs for_each.
- [3_containers](../../3_containers/) — Docker (лабы на Docker provider).
- Git — для модулей из Git-репозиториев и версий по тегам (`?ref=`). В
  этой базе Git не преподаётся; основы:
  [01_git_essentials](../../../4_python_my_knowledgebase/0_tooling_and_workflow/01_git_essentials/)
  (соседний репозиторий). Для темы достаточно понимать, что такое
  коммит, тег и URL репозитория.

## Файлы

- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: источники, версии, providers.
- [01_theory/terraform_modules.md](./01_theory/terraform_modules.md) —
  структура модуля, источники, передача провайдеров, версионирование.
- [02_examples/main.tf](./02_examples/main.tf) — вызовы модуля, в том
  числе через `for_each`; сам модуль —
  [02_examples/modules/nginx_container/](./02_examples/modules/nginx_container/)
  (`main.tf`, `variables.tf` с validation, `outputs.tf`).
- [03_exercises/README.md](./03_exercises/README.md) — 3 упражнения,
  🐳 Tier 1.
- [04_exercises_answers/modules-answers.md](./04_exercises_answers/modules-answers.md) —
  ответы.

## Как проходить

1. Прочитать теорию.
2. Разобрать пример: `terraform init` (подтягивает модули), `plan`,
   найти в плане адреса `module.nginx_extra["qa"]...`.
3. Сделать упражнения 01 → 02 → 03 в одной рабочей директории.
4. Сверить с ответами, `terraform destroy`.

## Когда двигаться дальше

- Можете без подсказки вынести ресурсы в модуль с variables/outputs и
  вызвать его через `for_each`.
- Можете объяснить, почему модуль не должен содержать блок `provider`.
- Можете объяснить, что произойдёт с адресами при переходе с отдельных
  `module`-блоков на `for_each` и как этого избежать (`moved`).

Следующая тема: [03_terraform_state](../03_terraform_state/).
