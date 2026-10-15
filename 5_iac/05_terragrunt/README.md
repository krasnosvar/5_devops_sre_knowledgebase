# 05. Terragrunt

## Зачем

Когда инфраструктура разбита на десятки стеков (окружения × регионы ×
слои), одинаковые `backend`/`provider` копируются в каждую папку, а
порядок `apply` между стеками держится в голове. Terragrunt убирает
этот бойлерплейт и строит граф зависимостей между директориями.

## Пререквизиты

- [02_terraform_modules](../02_terraform_modules/) — модули и их входы.
- [03_terraform_state](../03_terraform_state/) — S3 backend,
  `use_lockfile`, декомпозиция state.

> **Забегание вперёд.** Примеры темы описывают AWS (S3 backend, провайдер
> `aws`, EKS-кластер). AWS подробно — в
> [7_compute_platforms/02_aws](../../7_compute_platforms/02_aws/),
> Kubernetes — в [4_kubernetes](../../4_kubernetes/). Для этой темы
> достаточно читать конфиги: учётные данные (`aws configure`), регион,
> S3-бакет. Применять примеры на реальном AWS не обязательно и дорого
> (EKS и NAT Gateway тарифицируются почасово; новые аккаунты с 15 июля
> 2025 получают ограниченный кредитный Free plan —
> [условия](https://aws.amazon.com/free/)).

## Файлы

- [01_theory/terragrunt.md](./01_theory/terragrunt.md) — DRY, generate,
  dependency, `run --all` (старое `run-all`).
- [02_examples/terragrunt.hcl](./02_examples/terragrunt.hcl) — корневой
  конфиг: общий S3 backend (`use_lockfile`) и генерация провайдера.
- [02_examples/eks-stack.hcl](./02_examples/eks-stack.hcl) — дочерний
  стек EKS с `dependency "vpc"` и `mock_outputs`.
- Без упражнений: осмысленная лаба требует реального облака
  (несколько стеков в AWS).

## Как проходить

1. Прочитать теорию.
2. Разобрать оба примера: что попадёт в сгенерированные `backend.tf` и
   `provider.tf`, откуда берётся `key` стейта, в каком порядке
   `run --all apply` пройдёт стеки.
3. Проверить формат локально: `terragrunt hclfmt --check` в
   `02_examples/` (не требует AWS).

## Когда двигаться дальше

- Можете объяснить, какую проблему решает Terragrunt и когда он лишний.
- Можете объяснить `dependency` + `mock_outputs` и порядок
  `run --all destroy`.
- Можете объяснить, кто на самом деле держит lock стейта при запуске
  через Terragrunt.

Следующая тема: [06_ansible](../06_ansible/).
