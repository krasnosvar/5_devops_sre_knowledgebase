# Раздел 14. System Design (Архитектура Систем и Инфраструктуры)

Канонический раздел по System Design — от фундаментальной архитектуры
приложений и баз данных до масштабирования кластеров, пайплайнов и IaC.
Здесь собрана вся язык-независимая теория, математические законы
производительности, паттерны распределённых систем и сквозные кейсы для
архитектурных собеседований.

> **Связь с языковыми репозиториями серии (Python и Go):**
> Этот раздел является **единым источником фундаментальной теории** для всех
> трёх баз знаний. Прикладная реализация этих паттернов в конкретных языках
> (с учётом особенностей рантайма CPython/GIL и планировщика Go G-M-P,
> стандартных библиотек, фреймворков и пулов соединений) с запускаемыми
> примерами кода и тренажёрами вынесена в:
> - **Python System Design**:
> [`../../4_python_my_knowledgebase/4_system_design/`](../../4_python_my_knowledgebase/4_system_design/)
> - **Go System Design**:
> [`../../3_go_my_knowledgebase/3_system_design/`](../../3_go_my_knowledgebase/3_system_design/)

## Подразделы

1. [01_architecture_and_api_styles](./01_architecture_and_api_styles/) —
   архитектура систем и сервисов: монолит, модульный монолит и микросервисы,
   антипаттерн «распределённый монолит», закон Конвея, 12-Factor App,
   Strangler Fig; внутренняя архитектура сервиса (Layered, Hexagonal / Ports
   & Adapters, Clean Architecture), стратегический и тактический DDD
   (Bounded Context, ACL, Entity, Value Object, Aggregate, Repository, Unit
   of Work), CQRS и Event Sourcing; сравнение REST, gRPC (Protobuf/HTTP/2) и
   GraphQL, роль API Gateway и BFF, Service Discovery и Service Mesh.

2. [02_performance_caching_and_scaling](./02_performance_caching_and_scaling/) —
   производительность, кэширование и масштабирование: триада
   Throughput/Latency/Concurrency, законы Литтла, Амдала, Гюнтера (USL) и
   нелинейный рост очередей Кингмана, методология профилирования (USE/RED,
   On-CPU vs Off-CPU Flame Graphs) и нагрузочного тестирования; многоуровневое
   кэширование (Browser → CDN → Reverse Proxy → L1 In-Process → L2 Redis →
   DB Buffer Pool), паттерны Cache-Aside, Read/Write-Through, Write-Behind и
   четыре аномалии кэша (Stampede, Avalanche, Penetration, Hot Key);
   вертикальное и горизонтальное масштабирование, C10k/C10M (`epoll`,
   `io_uring`, лимиты ядра), VM-флот (ASG, Immutable Infra) и Kubernetes
   (HPA/VPA/KEDA, Karpenter, Overprovisioning, защита БД через PgBouncer).

3. [03_distributed_components_and_data](./03_distributed_components_and_data/) —
   распределённые данные, брокеры и отказоустойчивость: репликация
   (Single-Leader, Multi-Leader, Quorum $W + R > N$), лаг репликации и
   гарантии чтения (Read-Your-Writes, Monotonic Reads), партиционирование и
   шардирование, Consistent Hashing с виртуальными узлами, теоремы CAP и
   PACELC, распределённые транзакции (2PC vs Saga), B-Tree vs LSM-Tree;
   сравнение Kafka, RabbitMQ и NATS, гарантии доставки, Transactional Outbox /
   Inbox, идемпотентные консьюмеры, DLQ и Backpressure; алгоритмы балансировки
   (Round Robin, Least Connections, Power of Two Choices), активные и
   пассивные Health Checks, Rate Limiting, Retries с Backoff & Jitter,
   Circuit Breaker, Bulkhead, Load Shedding и Graceful Shutdown в Kubernetes.

4. [04_single_vs_multi_cluster](./04_single_vs_multi_cluster/) — пределы
   одного кластера (etcd, control plane, scheduler); blast radius как
   главная причина деления; паттерны cluster-per-env/region/tenant/tier;
   multi-tenancy внутри одного кластера и `vCluster` как альтернатива;
   управление флотом кластеров (Cluster API, Karmada, ApplicationSets, GSLB).

5. [05_cicd_at_scale](./05_cicd_at_scale/) — CI/CD для тысяч хостов и сотен
   сервисов: build once deploy many, флот самохостинг раннеров и распределённый
   кэш, P2P-доставка образов (Dragonfly/Spegel), push vs pull конфигурация
   на масштабе, progressive delivery (canary/blue-green/волновая раскатка),
   миграции БД без даунтайма (Expand & Contract) и GitOps.

6. [06_iac_at_scale](./06_iac_at_scale/) — IaC для организации, а не для
   одной команды: монорепо vs полирепо, модули как внутренний продукт с
   SemVer-контрактом, разделение state по владению, Policy as Code
   (OPA/Sentinel) и FinOps (Infracost) как организационные гейты,
   дрифт-детект на масштабе тысяч ресурсов.

7. [07_case_studies_and_interview](./07_case_studies_and_interview/) —
   фреймворк прохождения System Design интервью (45–60 минут), расчёты «на
   салфетке» (QPS, пики, диски за 5 лет, трафик, RAM кэша), константы задержек
   и матрица выбора компонентов; сквозной разбор 4 классических систем:
   **Денежные переводы (Payments / Ledger)**, **Галерея медиа (Image Hosting)**,
   **Сокращатель ссылок (URL Shortener)** и **Лента новостей (News Feed)**.

> Наблюдаемость на масштабе (cardinality, federation/remote_write, sampling
> логов, мульти-кластерные дашборды) разобрана в профильном разделе —
> см.
> [`../8_observability/09_observability_at_scale/`](../8_observability/09_observability_at_scale/).

## Пререквизиты

- [1_linux_and_shell](../1_linux_and_shell/) и
  [2_networking](../2_networking/) — дескрипторы, `epoll`, TCP/IP, DNS,
  HTTP/2, L4/L7 балансировка.
- [4_kubernetes](../4_kubernetes/) — архитектура кластера, автомасштабирование,
  безопасность, GitOps.
- [5_iac](../5_iac/) и [6_cicd](../6_cicd/) — Terraform, Ansible, пайплайны.
- [8_observability](../8_observability/) и [9_sre](../9_sre/) — метрики
  USE/RED, трейсинг, SLO, capacity planning.

## Как проходить

Читать последовательно `01 → 02 → 03 → 04 → 05 → 06 → 07`:
- блоки `01–03` закладывают архитектурный фундамент распределённых приложений
  и данных;
- блоки `04–06` масштабируют саму платформу (кластеры, пайплайны, IaC);
- блок `07` собирает все знания в единую методологию проектирования и
  сквозные кейсы.

Параллельно с блоками `01–03` и `07` рекомендуется открывать соответствующие
практические разделы в репозиториях Python или Go и запускать живой код.

## Когда двигаться дальше

- Можете за 45 минут спроектировать высоконагруженную систему от сбора
  требований и расчёта цифр до схемы шардирования, кэширования и защиты от
  каскадных отказов.
- Можете объяснить, когда делить кластеры Kubernetes, и как CI/CD и IaC
  меняются при переходе к десяткам команд и тысячам хостов.
- Дальше: финальный проект
  [0_lab_setup/05_capstone_project](../0_lab_setup/05_capstone_project/) —
  собрать знакомые кирпичики в одну работающую систему.
