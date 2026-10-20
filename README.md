# DevOps / SRE / MLOps Knowledge Base

Учебная база по DevOps, SRE и MLOps: инфраструктура, оркестрация, IaC, CI/CD,
облака и bare metal, наблюдаемость, надёжность, безопасность и машинное
обучение в продакшне.

Материалы собраны как практический roadmap: краткая теория, конфиги и скрипты,
которые можно запускать, упражнения с готовыми лабораторными стендами.

## Связанные репозитории

Эта база — часть серии. Читай вместе:

| Репо | Что внутри |
|------|-----------|
| [`../1_sysadm_sre_devops_tools/`](../1_sysadm_sre_devops_tools/) | Практические команды, конфиги, скрипты — справочник по инструментам |
| [`../3_go_my_knowledgebase/`](../3_go_my_knowledgebase/) | Go: язык, concurrency, базы данных, system design — для автоматизации на Go |
| [`../4_python_my_knowledgebase/`](../4_python_my_knowledgebase/) | Python: язык, фреймворки, system design — для автоматизации на Python; там же — [Git essentials](../4_python_my_knowledgebase/0_tooling_and_workflow/01_git_essentials/) (workflow, branching/merging, conflicts) |

> **Разделение ролей:** `1_sysadm_sre_devops_tools` — команды и конфиги (как
> делать). Эта база — теория и понимание (почему так работает) + упражнения с
> лабами.

## Структура

- [0_lab_setup](./0_lab_setup/) — подготовка лабораторной среды для
  упражнений: Docker Compose, локальные VM (KVM / OrbStack / WSL2), локальный
  k8s (kind/k3d), облако и VPS.
- [1_linux_and_shell](./1_linux_and_shell/) — фундамент: процессная модель,
  cgroups, namespaces, файловые дескрипторы, systemd, bash-идиомы для DevOps,
  права доступа (ACL/NSS) и системный траблшутинг (USE, dmesg, OOM, I/O, eBPF).
- [2_networking](./2_networking/) — сетевые технологии и протоколы: OSI,
  TCP/IP, DNS, HTTP/HTTPS, балансировка нагрузки (L4/L7), BGP, iptables, VPC.
- [3_containers](./3_containers/) — Docker и Podman: OCI, image layers,
  overlay FS, rootless, security (capabilities, seccomp), multi-stage builds.
- [4_kubernetes](./4_kubernetes/) — Kubernetes от первых шагов (kind, kubectl,
  первый Pod/Deployment/Service) до GitOps: control/data plane, scheduling,
  Helm, Kustomize, ArgoCD, RBAC, NetworkPolicy, day-2 operations и глубокий
  траблшутинг инцидентов.
- [5_iac](./5_iac/) — Infrastructure as Code: Terraform/OpenTofu (state,
  модули, workspaces), Terragrunt, Ansible (роли, идемпотентность), сравнение
  подходов.
- [6_cicd](./6_cicd/) — CI/CD пайплайны: теория, GitLab CI, GitHub Actions,
  GitOps (push-based vs pull-based), secrets в пайплайнах.
- [7_compute_platforms](./7_compute_platforms/) — облака (AWS/GCP/Azure),
  bare metal (IPMI/BMC, PXE, MAAS), on-prem виртуализация (VMware, Proxmox),
  гибридные паттерны.
- [8_observability](./8_observability/) — наблюдаемость: метрики
  (RED/USE/Golden Signals, Prometheus, VictoriaMetrics), логи (Loki), трейсинг
  (OTel, Jaeger/Tempo), алертинг, дашборды.
- [9_sre](./9_sre/) — SRE практики: SLO/SLI/SLA, error budget, incident
  management, post-mortem, chaos engineering, on-call hygiene.
- [10_devsecops](./10_devsecops/) — DevSecOps: k8s RBAC, secrets management
  (Vault), Network Policy, image scanning, SAST/DAST в CI, supply chain (SBOM,
  Sigstore). Основы security по каждому слою стека — рядом со слоем:
  `1_linux_and_shell/09_linux_security`, `3_containers/05_security`,
  `4_kubernetes/06_security`.
- [11_mlops](./11_mlops/) — MLOps и LLMOps: окружение (`uv`, `k3d`), lifecycle,
  экосистема Hugging Face и реестры моделей (`ORAS`), валидация данных
  (`Pandera`, `DVC`), трекинг (`MLflow`, `ClearML`), пайплайны обучения,
  serving (`ONNX Runtime`, `llama.cpp`/`Ollama`/`vLLM`, `LiteLLM`), CI/CD и
  Quality Gates, Feature Stores (`Feast`), мониторинг дрейфа (`Evidently`),
  RAG и оценка (`Qdrant`, `RAGAS`, `Langfuse`), AI DevSecOps (`Huntr`,
  `ModelScan`, `Presidio`), CPU/iGPU/GPU-инфраструктура и сквозной проект
  «Личная база документов».
- [12_interview_questions_prep](./12_interview_questions_prep/) —
  вопросы-ответы для подготовки к DevOps/SRE интервью: Linux (процессы, сеть,
  ФС, bash), сети, Docker, Kubernetes, CI/CD, Terraform, Ansible, мониторинг,
  базы данных, Git, облака (AWS/GCP/Azure/Yandex), DevSecOps, MLOps, Python,
  Go, system design.
- [13_books_certs_resources](./13_books_certs_resources/) — практические
  сертификации (CKA/CKAD/CKS, AWS, Terraform) и проверенные книги/курсы/ресурсы.
- [14_system_design](./14_system_design/) — канонический раздел по System
  Design (общий фундамент для DevOps/SRE, Python и Go): монолит и микросервисы,
  Clean Architecture и DDD, стили API (REST, gRPC, GraphQL), профилирование и
  узкие места, многоуровневое кэширование и масштабирование (VM и Kubernetes),
  репликация, шардирование, CAP/PACELC, брокеры (Kafka, RabbitMQ, NATS),
  балансировка и отказоустойчивость, один кластер против нескольких, CI/CD и
  IaC на масштабе организации, фреймворк System Design интервью и 4 сквозных
  архитектурных кейса.

## Шпаргалки (`CHEATSHEET.md`)

В каждой теме разделов `0_lab_setup`–`11_mlops` и `14_system_design` рядом с
`README.md` лежит одноэкранная шпаргалка `CHEATSHEET.md` с таблицами выбора,
командами диагностики и частыми ловушками (`⚠️`). Шпаргалки раздела 14 (System
Design):

- [14.01 Архитектура, Clean/DDD и стили API](./14_system_design/01_architecture_and_api_styles/CHEATSHEET.md)
- [14.02 Производительность, кэширование и масштабирование](./14_system_design/02_performance_caching_and_scaling/CHEATSHEET.md)
- [14.03 Распределённые данные, очереди и отказоустойчивость](./14_system_design/03_distributed_components_and_data/CHEATSHEET.md)
- [14.04 Один кластер или много](./14_system_design/04_single_vs_multi_cluster/CHEATSHEET.md)
- [14.05 CI/CD на масштабе](./14_system_design/05_cicd_at_scale/CHEATSHEET.md)
- [14.06 IaC на масштабе организации](./14_system_design/06_iac_at_scale/CHEATSHEET.md)
- [14.07 System Design интервью и сквозные кейсы](./14_system_design/07_case_studies_and_interview/CHEATSHEET.md)

## Пререквизиты

- Уверенная работа в терминале Linux/macOS (cd, ls, редактор).
- **Git** в этой базе не преподаётся, но нужен с первых упражнений (стенды,
  CI/CD, GitOps). Если git ещё не освоен — пройдите блок
[Git essentials](../4_python_my_knowledgebase/0_tooling_and_workflow/01_git_essentials/)
  в соседнем Python-репозитории: clone/commit/branch/merge, разрешение
  конфликтов, remote.
- Базовое чтение YAML — используется почти в каждом разделе.

## Формат разделов

Большинство тем устроены по одному шаблону:

- `01_theory/` — глубокая теория без лишней воды: почему так, а не как;
- `02_examples/` — конфиги, манифесты, скрипты, которые можно запускать;
- `03_exercises/` — упражнения с лабораторными стендами (Docker Compose или
  Terraform);
- `04_exercises_answers/` — эталонные решения для самопроверки в `.md`:
  команды по порядку, ожидаемый вывод и короткое объяснение;
- `README.md` и `CHEATSHEET.md` — навигация и быстрая шпаргалка по теме.

Каждое упражнение указывает **минимальный тир лабы**, необходимый для его
выполнения:
- 🐳 **Tier 1** — только Docker Compose, работает везде
- 🖥 **Tier 2** — локальные VM (KVM / OrbStack / WSL2+VirtualBox)
- ☁️ **Tier 3** — облако или VPS (AWS — с июля 2025 новые аккаунты получают
  кредитный Free plan вместо 12-месячного free tier; Hetzner)

## Как проходить

1. Начать с [0_lab_setup](./0_lab_setup/) — поднять минимальную среду (хватит
   Tier 1 для большинства разделов). Финальный проект
   `0_lab_setup/05_capstone_project` пока пропустить — см. пункт 9.
2. Пройти [1_linux_and_shell](./1_linux_and_shell/),
   [2_networking](./2_networking/) и [3_containers](./3_containers/) как
   фундамент — это то, на чём строится всё остальное.
3. Перейти к [4_kubernetes](./4_kubernetes/) и [5_iac](./5_iac/) — основа
   современного DevOps-стека.
4. Параллельно читать [8_observability](./8_observability/) — наблюдаемость
   нужна с первого же поднятого сервиса.
5. [6_cicd](./6_cicd/), [7_compute_platforms](./7_compute_platforms/),
   [9_sre](./9_sre/), [10_devsecops](./10_devsecops/) — по порядку или по
   задаче.
6. [11_mlops](./11_mlops/) — отдельный трек, можно проходить параллельно с
   основным после освоения k8s.
7. [12_interview_questions_prep](./12_interview_questions_prep/) и
   [13_books_certs_resources](./13_books_certs_resources/) — справочники,
   открывать по необходимости.
8. [14_system_design](./14_system_design/) — раздел-синтез и каноническая
   теория архитектуры систем, после освоения `4_kubernetes`, `5_iac`,
   `6_cicd`, `8_observability`, `9_sre`.
9. **Финальный проект** —
   [0_lab_setup/05_capstone_project](./0_lab_setup/05_capstone_project/):
   одно приложение проходит путь от голого Linux до k8s, IaC, CI/CD,
   наблюдаемости, SRE-инцидента и security. Делается **в конце**, а не на
   шаге 0, хотя лежит в `0_lab_setup`. Каждый этап открывается после своего
   раздела: 01 → после `1_linux_and_shell`, 02 → `3_containers`,
   03 → `4_kubernetes`, 04 → `5_iac`, 05 → `6_cicd`,
   06 → `8_observability`, 07 → `9_sre`, 08 → `10_devsecops`.

## Полезные ресурсы

- [Google SRE Book](https://sre.google/sre-book/table-of-contents/) —
  бесплатно онлайн, классика
- [The Phoenix Project](https://itrevolution.com/product/the-phoenix-project/)
  — роман про DevOps-трансформацию
- [roadmap.sh/devops](https://roadmap.sh/devops) — интерактивный roadmap
- [Kubernetes docs](https://kubernetes.io/docs/) — официальная документация
- [Terraform docs](https://developer.hashicorp.com/terraform/docs)
- [CNCF Landscape](https://landscape.cncf.io/) — карта облачно-нативных
  инструментов
- [Killercoda](https://killercoda.com/) — бесплатные интерактивные лабы (k8s,
  Linux)
- [KodeKloud](https://kodekloud.com/) — практические курсы с лабами (CKA,
  Terraform, GitOps)
