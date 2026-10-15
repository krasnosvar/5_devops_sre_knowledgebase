# Раздел 5. Infrastructure as Code

Terraform/OpenTofu, Terragrunt, Ansible: как описывать инфраструктуру кодом,
управлять состоянием и делать это воспроизводимо и безопасно.

> Команды и примеры TF →
> [`../1_sysadm_sre_devops_tools/.../terraform/`](../../1_sysadm_sre_devops_tools/1_linux/2_services/1_infra_terraform_clouds/terraform/)

## Пререквизиты

- [1_linux_and_shell](../1_linux_and_shell/) — shell, SSH, права, systemd:
  Ansible управляет именно Linux-хостами по SSH.
- [3_containers](../3_containers/) — `docker run`/`docker ps`/`docker rm`:
  все Terraform-лабы Tier 1 используют Docker provider.
- [0_lab_setup/02_local_vms](../0_lab_setup/02_local_vms/) — локальные VM
  (KVM/OrbStack/WSL2): стенд для Ansible (Tier 2).
- Git — в этой базе не преподаётся; нужен для версионирования модулей и
  GitOps для инфраструктуры. Основы:
  [01_git_essentials](../../4_python_my_knowledgebase/0_tooling_and_workflow/01_git_essentials/)
  (соседний репозиторий).

> **Забегание вперёд.** Часть примеров (S3 backend, Terragrunt, EKS)
> использует AWS, который подробно разбирается в
> [7_compute_platforms/02_aws](../7_compute_platforms/02_aws/). Для этого
> раздела достаточно понимать: учётные данные (`aws configure` или
> `AWS_PROFILE`), регион, S3-бакет. Все упражнения раздела проходятся
> без AWS-аккаунта (Docker, локальный S3, VM).

## Подразделы

1. [01_terraform_core](./01_terraform_core/) — как работает Terraform изнутри:
   state (что хранит, зачем lock), plan/apply граф зависимостей, refresh,
   почему `terraform destroy` опасен в CI без ограничений `-target`.

2. [02_terraform_modules](./02_terraform_modules/) — написание переиспользуемых
   модулей: input/output variables, locals, for_each vs count, conditional
   ресурсы; версионирование модулей через Git tags.

3. [03_terraform_state](./03_terraform_state/) — backend (S3 с lock-файлом
   `use_lockfile`, устаревшая схема с DynamoDB, Terraform Cloud); state
   isolation стратегии (по workspace vs по директории); импорт
   существующей инфраструктуры; аварийный state recovery.

4. [04_opentofu](./04_opentofu/) — OpenTofu: что отличается от Terraform после
   форка, миграция с TF на OpenTofu, OTF-специфичные возможности (encryption
   state at rest, provider functions).

5. [05_terragrunt](./05_terragrunt/) — Terragrunt как DRY-обёртка: один
   корневой конфиг backend для всех окружений, dependency graph между
   стеками, generate блоки, `run --all` (старое `run-all`); когда
   Terragrunt оправдан, а когда усложняет.

6. [06_ansible](./06_ansible/) — Ansible: inventory (static/dynamic), роли
   (структура, galaxy), idempotency и почему это не всегда бесплатно; handlers,
   vault для секретов; сравнение с Terraform: конфигурация vs провижининг.

7. [07_iac_patterns](./07_iac_patterns/) — архитектурные паттерны IaC:
   layered stacks (сеть → вычисления → приложение), immutable vs mutable
   infrastructure, drift detection, GitOps для инфраструктуры.

## Как проходить

01 → 02 → 03 — Terraform core, без пропусков. 04 и 05 — по необходимости.
06 — Ansible параллельно с Terraform (дополняют друг друга). 07 — после опыта
с обоими инструментами.

## Упражнения — тиры

- 🐳 Tier 1: Terraform + Docker provider (планирование и state без
  реальной инфраструктуры; remote state — локальный S3 в Docker).
- 🖥 Tier 2: Terraform + libvirt (Linux) или VirtualBox
  (cross-platform) — создание VM; Ansible поверх них.
- ☁️ Tier 3: Terraform + AWS (реальный cloud) — по желанию, обязательных
  упражнений на AWS в разделе нет. Важно: с 15 июля 2025 новые
  AWS-аккаунты получают кредитный Free plan (ограниченная сумма
  кредитов и срок) вместо прежнего 12-месячного free tier; актуальные
  условия — на [aws.amazon.com/free](https://aws.amazon.com/free/).
  Гигиена расходов: AWS Budgets с алертом, тег на каждый ресурс,
  `terraform destroy` в конце каждой сессии, не оставлять NAT Gateway,
  EKS и балансировщики на ночь.

## Когда двигаться дальше

- Можете без подсказки написать конфигурацию с variables/outputs и
  модулем, пройти цикл `init → plan -out → apply → destroy`.
- Можете объяснить, что хранится в state, как работает блокировка
  (`use_lockfile`) и чем `state rm` отличается от `destroy`.
- Можете написать идемпотентный Ansible playbook с ролью и handlers и
  доказать идемпотентность повторным запуском (`changed=0`).

Следующий раздел: [6_cicd](../6_cicd/) — те же `plan`/`apply` и
playbook'и, но запущенные из пайплайна.
