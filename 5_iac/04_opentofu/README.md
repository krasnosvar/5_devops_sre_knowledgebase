# 04. OpenTofu

## Зачем

После смены лицензии Terraform на BSL появился открытый форк —
OpenTofu. На работе встретится выбор «Terraform или OpenTofu» и
миграция между ними. Здесь — откуда форк, насколько он совместим,
что в нём есть своего (шифрование state, ранняя оценка переменных) и
как устроен его реестр.

## Пререквизиты

- [01_terraform_core](../01_terraform_core/) и
  [03_terraform_state](../03_terraform_state/) — HCL, state, backend:
  OpenTofu использует их без изменений.

> **Забегание вперёд.** В теории упоминаются AWS S3 и KMS (шифрование
> state). AWS подробно — в
> [7_compute_platforms/02_aws](../../7_compute_platforms/02_aws/); здесь
> достаточно знать, что KMS хранит ключи шифрования, а S3 — объекты.

## Файлы

- [01_theory/opentofu.md](./01_theory/opentofu.md) — лицензия, drop-in
  совместимость, state encryption, OpenTofu Registry.
- Без примеров и упражнений: тема справочная. Любой пример из
  [01_terraform_core/02_examples/](../01_terraform_core/02_examples/)
  запускается и через `tofu` (`tofu init && tofu plan`).

## Как проходить

1. Прочитать теорию.
2. Установить `tofu` и прогнать пример из темы 01 командами
   `tofu init`, `tofu plan -out=tfplan`, `tofu apply tfplan`,
   `tofu destroy` — убедиться в совместимости.

## Когда двигаться дальше

- Можете объяснить разницу BSL и MPL и кому реально мешает BSL.
- Можете объяснить, что делает state encryption и чем оно лучше
  SSE-KMS на бакете.
- Можете объяснить, как устроен публичный OpenTofu Registry и для чего
  в OpenTofu 1.10 появилась опциональная поддержка OCI-реестров.

Следующая тема: [05_terragrunt](../05_terragrunt/).
