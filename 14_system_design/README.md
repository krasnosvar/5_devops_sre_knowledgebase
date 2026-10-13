# Раздел 14. System Design для DevOps/SRE

Как связать темы из всех предыдущих разделов в архитектурные решения:
когда один кластер, а когда много; как раскатывать CI/CD на тысячи хостов;
как описывать инфраструктуру для десятков команд. Это не новые инструменты
— это решения, из каких уже знакомых кирпичиков собирать высоконагруженную
систему и почему именно так.

## Подразделы

1. [01_scaling_high_load_systems](./01_scaling_high_load_systems/) —
   масштабирование без Kubernetes (VM/bare-metal fleet: ASG, immutable infra)
   и с Kubernetes (HPA/VPA/KEDA, overprovisioning под всплески); stateless vs
   stateful нагрузка; типичные узкие места (connection storm, cache
   stampede, пределы ОС).

2. [02_single_vs_multi_cluster](./02_single_vs_multi_cluster/) — пределы
   одного кластера (etcd, control plane, scheduler); blast radius как
   главная причина деления; паттерны cluster-per-env/region/tenant/tier;
   multi-tenancy внутри одного кластера как альтернатива; управление флотом
   кластеров (Cluster API, Karmada, ApplicationSets).

3. [03_cicd_at_scale](./03_cicd_at_scale/) — CI/CD для тысяч хостов/сервисов:
   build once deploy many, флот самохостинг раннеров и кэширование,
   push vs pull конфигурация на масштабе, progressive delivery (canary/
   blue-green/волновая раскатка) для тысяч инстансов, GitOps как ответ на
   масштаб.

4. [04_iac_at_scale](./04_iac_at_scale/) — IaC для организации, а не для
   одной команды: монорепо vs полирепо, модули как внутренний продукт с
   SemVer-контрактом, разделение state по владению, Policy as Code как
   организационный гейт, дрифт-детект на масштабе тысяч ресурсов.

> Наблюдаемость на масштабе (cardinality, federation/remote_write, sampling
> логов, мульти-кластерные дашборды) вынесена рядом со своим слоем —
> см. [`../8_observability/09_observability_at_scale/`](../8_observability/09_observability_at_scale/).

## Как проходить

Читать после освоения базовых разделов (`4_kubernetes`, `5_iac`, `6_cicd`,
`8_observability`, `9_sre`) — это раздел-синтез, использующий их терминологию
без повторного объяснения. 01 → 02 → 03 → 04 читать последовательно, каждый
опирается на предыдущий (масштаб приложения → масштаб кластера →
масштаб раскатки → масштаб описания инфраструктуры).
