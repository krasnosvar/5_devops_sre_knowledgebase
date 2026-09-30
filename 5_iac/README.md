# Раздел 4. Infrastructure as Code

Terraform/OpenTofu, Terragrunt, Ansible: как описывать инфраструктуру кодом,
управлять состоянием и делать это воспроизводимо и безопасно.

> Команды и примеры TF → [`../1_sysadm_sre_devops_tools/.../terraform/`](../../1_sysadm_sre_devops_tools/1_linux/2_services/1_infra_terraform_clouds/terraform/)

## Подразделы

1. [01_terraform_core](./01_terraform_core/) — как работает Terraform изнутри:
   state (что хранит, зачем lock), plan/apply граф зависимостей, refresh,
   почему `terraform destroy` опасен в CI без ограничений `-target`.

2. [02_terraform_modules](./02_terraform_modules/) — написание переиспользуемых
   модулей: input/output variables, locals, for_each vs count, conditional
   ресурсы; версионирование модулей через Git tags.

3. [03_terraform_state](./03_terraform_state/) — backend (S3 + DynamoDB lock,
   Terraform Cloud); state isolation стратегии (по workspace vs по директории);
   импорт существующей инфраструктуры; аварийный state recovery.

4. [04_opentofu](./04_opentofu/) — OpenTofu: что отличается от Terraform после
   форка, миграция с TF на OpenTofu, OTF-специфичные возможности (encryption
   state at rest, provider functions).

5. [05_terragrunt](./05_terragrunt/) — Terragrunt как DRY-обёртка: один backend.hcl
   для всех окружений, dependency graph между стеками, generate блоки,
   run-all команды; когда Terragrunt оправдан, а когда усложняет.

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

🐳 Tier 1: Terraform + Docker provider (планирование и state без реальной инфраструктуры)
🖥 Tier 2: Terraform + libvirt (Linux) или VirtualBox (cross-platform) — создание VM
☁️ Tier 3: Terraform + AWS (реальный cloud, free tier достаточно)
