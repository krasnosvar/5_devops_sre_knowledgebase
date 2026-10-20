# 07. SAST и статический анализ в CI

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — команды и шаблоны одним экраном.

## Зачем
Уязвимость в коде или открытый S3 bucket в Terraform дешевле всего
поймать в merge request, а не в production. Тема: какие сканеры ставить
на каждый слой (код, IaC, Dockerfile, манифесты) и как встроить их в CI
без превращения pipeline в узкое место.

## Пререквизиты
- [6_cicd/02_gitlab_ci](../../6_cicd/02_gitlab_ci/) — синтаксис
  `.gitlab-ci.yml`.
- [5_iac](../../5_iac/) — Terraform, который сканируется.

## Файлы
- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: сканеры по слоям, CI-отчёты.
- [01_theory/sast_in_ci.md](./01_theory/sast_in_ci.md) — Semgrep,
  Checkov, trivy config (бывший tfsec), Trivy, kubesec, hadolint,
  полный security pipeline.
- [02_examples/.gitlab-ci.yml](./02_examples/.gitlab-ci.yml) — security
  stage для GitLab CI.
- Упражнений нет: сканеры запускаются локально на своём коде по
  командам из теории (🐳 Tier 1).

## Как проходить
1. Прочитать теорию.
2. Локально прогнать Semgrep, `trivy config` и hadolint на своём проекте.
3. Разобрать `.gitlab-ci.yml` и перенести нужные job в свой pipeline.

## Когда двигаться дальше
- Можете объяснить, какой сканер на каком слое и где они пересекаются.
- Можете настроить падение pipeline только на HIGH/CRITICAL.

Далее: [08_runtime_security](../08_runtime_security/).
