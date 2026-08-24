# Раздел 0. Лабораторная среда (Lab Setup)

Прежде чем переходить к упражнениям — нужна среда для их выполнения.
В отличие от Go/Python, где достаточно запустить файл, DevOps-упражнения
требуют живой инфраструктуры: хостов, сетей, кластеров.

Раздел описывает три уровня сложности лабы и как их поднять на Linux, macOS и Windows.

## Уровни лабораторной среды

| Тир | Что нужно | Для каких разделов |
|-----|-----------|-------------------|
| 🐳 **Tier 1** — Docker Compose | Docker + docker compose | Мониторинг, CI/CD инструменты, базы данных, Vault, ArgoCD поверх kind |
| 🖥 **Tier 2** — Локальные VM | KVM / OrbStack / WSL2+VirtualBox + Terraform | Ansible, kubeadm, bare metal provisioning, многоузловые k8s |
| ☁️ **Tier 3** — Облако / VPS | AWS free tier / Hetzner (~€4/мес) | Cloud-специфика (IAM, S3, managed k8s), внешний IP, multi-node |

> Большинство упражнений базы работают на **Tier 1**. Tier 2 нужен для разделов
> Kubernetes (полная установка), IaC (Ansible по SSH) и Compute Platforms.

## Подразделы

1. [01_docker_compose](./01_docker_compose/) — установка Docker, базовые команды,
   compose quickstart; именно отсюда стартуют большинство лабораторных стендов.
2. [02_local_vms](./02_local_vms/) — локальные VM по платформе:
   - `linux_kvm/` — KVM+QEMU+libvirt+Terraform (рекомендуемый Linux-сетап)
   - `macos_orbstack/` — OrbStack (лучший вариант на macOS, включая Apple Silicon)
   - `windows_wsl2/` — WSL2 + VirtualBox + Terraform
3. [03_local_k8s](./03_local_k8s/) — локальный Kubernetes: kind (поверх Docker),
   k3d (k3s в Docker), minikube; когда что выбрать.
4. [04_cloud_vps](./04_cloud_vps/) — AWS free tier и Hetzner Cloud как дешёвые
   альтернативы; Terraform для провижининга.

## Принцип стендов

Каждое упражнение в базе поставляется со стендом — одним из двух:

```
раздел/03_exercises/01_some_exercise/
├── docker-compose.yml   ← Tier 1: docker compose up -d
└── lab/                 ← Tier 2/3: terraform apply
    ├── main.tf
    ├── variables.tf
    └── README.md
```

Terraform-провайдер выбирается по платформе, интерфейс (переменные, outputs)
остаётся одинаковым — упражнение работает на любом тире.
