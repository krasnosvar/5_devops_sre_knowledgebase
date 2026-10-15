# 07. IaC patterns

## Зачем

Знать Terraform и Ansible мало — нужно решить, как разложить код по
слоям, где хранить секреты, как ловить ручные изменения и кто вообще
имеет право делать `apply`. Здесь — архитектурные паттерны, которые
обсуждают на дизайн-ревью и собеседованиях.

## Пререквизиты

- [01_terraform_core](../01_terraform_core/) —
  [03_terraform_state](../03_terraform_state/) и
  [06_ansible](../06_ansible/) — оба инструмента на практике.
- Git — основа «PR-driven» процесса для инфраструктуры. В этой базе не
  преподаётся; основы:
  [01_git_essentials](../../../4_python_my_knowledgebase/0_tooling_and_workflow/01_git_essentials/)
  (соседний репозиторий): ветка, pull request, ревью, merge.

> **Забегание вперёд.** Примеры паттернов используют AWS (AMI, ASG, SSM
> Parameter Store, AWS Config) и CI/CD. AWS подробно — в
> [7_compute_platforms/02_aws](../../7_compute_platforms/02_aws/), CI/CD —
> в [6_cicd](../../6_cicd/). Для этой темы достаточно понимать названия
> сервисов на уровне «что это».

## Файлы

- [01_theory/iac_patterns.md](./01_theory/iac_patterns.md) — immutable vs
  mutable, GitOps для инфраструктуры, секреты, drift, слои state.
- Без примеров и упражнений: паттерны архитектурные, их практика —
  в CI ([6_cicd](../../6_cicd/)) и в
  [финальном проекте](../../0_lab_setup/05_capstone_project/).

## Как проходить

1. Прочитать теорию.
2. Для своей (или учебной) инфраструктуры набросать разбиение на слои
   и способ drift detection (`plan -detailed-exitcode` по крону).

## Когда двигаться дальше

- Можете объяснить immutable vs mutable и где граница с Ansible.
- Можете описать PR-driven процесс для Terraform и кто держит ключи.
- Можете объяснить, почему секреты попадают в state и как это
  ограничить (шифрование, ephemeral-значения).

Следующий раздел: [6_cicd](../../6_cicd/).
