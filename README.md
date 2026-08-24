# DevOps / SRE / MLOps Knowledge Base

Учебная база по DevOps, SRE и MLOps: инфраструктура, оркестрация, IaC, CI/CD,
облака и bare metal, наблюдаемость, надёжность, безопасность и машинное обучение
в продакшне.

Материалы собраны как практический roadmap: краткая теория, конфиги и скрипты
которые можно запускать, упражнения с готовыми лабораторными стендами.

## Связанные репозитории

Эта база — часть серии. Читай вместе:

| Репо | Что внутри |
|------|-----------|
| [`../1_sysadm_sre_devops_tools/`](../1_sysadm_sre_devops_tools/) | Практические команды, конфиги, скрипты — справочник по инструментам |
| [`../3_go_my_knowledgebase/`](../3_go_my_knowledgebase/) | Go: язык, concurrency, базы данных, system design — для автоматизации на Go |
| [`../4_python_my_knowledgebase/`](../4_python_my_knowledgebase/) | Python: язык, фреймворки, system design — для автоматизации на Python |

> **Разделение ролей:** `1_sysadm_sre_devops_tools` — команды и конфиги (как делать).
> Эта база — теория и понимание (почему так работает) + упражнения с лабами.

## Структура

- [0_lab_setup](./0_lab_setup/) — подготовка лабораторной среды для упражнений:
  Docker Compose, локальные VM (KVM / OrbStack / WSL2), локальный k8s (kind/k3d),
  облако и VPS.
- [1_linux_and_shell](./1_linux_and_shell/) — фундамент: процессная модель, cgroups,
  namespaces, файловые дескрипторы, systemd, bash-идиомы для DevOps.
- [2_containers](./2_containers/) — Docker и Podman: OCI, image layers, overlay FS,
  rootless, security (capabilities, seccomp), multi-stage builds.
- [3_kubernetes](./3_kubernetes/) — Kubernetes от архитектуры до GitOps: control/data
  plane, scheduling, Helm, Kustomize, ArgoCD, RBAC, NetworkPolicy.
- [4_iac](./4_iac/) — Infrastructure as Code: Terraform/OpenTofu (state, модули,
  workspaces), Terragrunt, Ansible (роли, идемпотентность), сравнение подходов.
- [5_cicd](./5_cicd/) — CI/CD пайплайны: теория, GitLab CI, GitHub Actions, GitOps
  (push-based vs pull-based), secrets в пайплайнах.
- [6_compute_platforms](./6_compute_platforms/) — облака (AWS/GCP/Azure), bare metal
  (IPMI/BMC, PXE, MAAS), on-prem виртуализация (VMware, Proxmox), гибридные паттерны.
- [7_observability](./7_observability/) — наблюдаемость: метрики (RED/USE/Golden
  Signals, Prometheus, VictoriaMetrics), логи (Loki), трейсинг (OTel, Jaeger/Tempo),
  алертинг, дашборды.
- [8_sre](./8_sre/) — SRE практики: SLO/SLI/SLA, error budget, incident management,
  post-mortem, chaos engineering, on-call hygiene.
- [9_security](./9_security/) — DevSecOps: k8s RBAC, secrets management (Vault),
  Network Policy, image scanning, SAST/DAST в CI, supply chain (SBOM, Sigstore).
- [10_mlops](./10_mlops/) — MLOps и LLMOps: lifecycle моделей, experiment tracking,
  training pipelines, model serving, мониторинг моделей, LLM в продакшне, GPU
  инфраструктура (consumer, datacenter, cloud).
- [other](./other/) — интервью DevOps/SRE, карьерный roadmap, книги, сертификации.

## Формат разделов

Большинство тем устроены по одному шаблону:

- `01_theory/` — краткая теория без лишней воды: почему так, а не как;
- `02_examples/` — конфиги, манифесты, скрипты, которые можно запускать;
- `03_exercises/` — упражнения с лабораторными стендами (Docker Compose или Terraform);
- `04_exercises_answers/` — эталонные решения для самопроверки;
- `README.md` — навигация по теме.

Каждое упражнение указывает **минимальный тир лабы**, необходимый для его выполнения:
- 🐳 **Tier 1** — только Docker Compose, работает везде
- 🖥 **Tier 2** — локальные VM (KVM / OrbStack / WSL2+VirtualBox)
- ☁️ **Tier 3** — облако или VPS (AWS free tier / Hetzner)

## Как проходить

1. Начать с [0_lab_setup](./0_lab_setup/) — поднять минимальную среду (хватит Tier 1
   для большинства разделов).
2. Пройти [1_linux_and_shell](./1_linux_and_shell/) и [2_containers](./2_containers/)
   как фундамент — это то, на чём строится всё остальное.
3. Перейти к [3_kubernetes](./3_kubernetes/) и [4_iac](./4_iac/) — основа современного
   DevOps-стека.
4. Параллельно читать [7_observability](./7_observability/) — наблюдаемость нужна
   с первого же поднятого сервиса.
5. [5_cicd](./5_cicd/), [6_compute_platforms](./6_compute_platforms/),
   [8_sre](./8_sre/), [9_security](./9_security/) — по порядку или по задаче.
6. [10_mlops](./10_mlops/) — отдельный трек, можно проходить параллельно с основным
   после освоения k8s.
7. [other](./other/) — справочник, открывать по необходимости.

## Полезные ресурсы

- [Google SRE Book](https://sre.google/sre-book/table-of-contents/) — бесплатно онлайн, классика
- [The Phoenix Project](https://itrevolution.com/product/the-phoenix-project/) — роман про DevOps-трансформацию
- [roadmap.sh/devops](https://roadmap.sh/devops) — интерактивный roadmap
- [Kubernetes docs](https://kubernetes.io/docs/) — официальная документация
- [Terraform docs](https://developer.hashicorp.com/terraform/docs)
- [CNCF Landscape](https://landscape.cncf.io/) — карта облачно-нативных инструментов
- [Killercoda](https://killercoda.com/) — бесплатные интерактивные лабы (k8s, Linux)
- [KodeKloud](https://kodekloud.com/) — практические курсы с лабами (CKA, Terraform, GitOps)
