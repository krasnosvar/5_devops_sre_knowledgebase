# Раздел 0. Лабораторная среда (Lab Setup)

Прежде чем переходить к упражнениям — нужна среда для их выполнения.
В отличие от Go/Python, где достаточно запустить файл, DevOps-упражнения
требуют живой инфраструктуры: хостов, сетей, кластеров.

Раздел описывает три уровня сложности лабы и как их поднять на Linux,
macOS и Windows, а также содержит сквозной финальный проект курса.

## Пререквизиты

Раздел стартовый, других разделов базы не требует. Нужны:

- уверенная работа в терминале (cd, ls, редактор, SSH-ключи);
- машина с 8+ GB RAM (16 GB комфортнее) и включённой аппаратной
  виртуализацией.

Docker, Terraform и kubectl здесь используются раньше, чем разбираются
в своих разделах; в каждой теме есть пометка «Забегание вперёд» с
минимумом команд и ссылкой на полный разбор.

## Уровни лабораторной среды

| Тир | Что нужно | Для каких разделов |
|-----|-----------|-------------------|
| 🐳 **Tier 1** — Docker Compose | Docker + docker compose | Мониторинг, CI/CD инструменты, базы данных, Vault, ArgoCD поверх kind |
| 🖥 **Tier 2** — Локальные VM | KVM+Terraform / OrbStack / WSL2+Vagrant/Multipass | Ansible, kubeadm, bare metal provisioning, многоузловые k8s |
| ☁️ **Tier 3** — Облако / VPS | AWS Free Tier (кредиты) / Hetzner (~€4/мес) | Cloud-специфика (IAM, S3, managed k8s), внешний IP, multi-node |

> Большинство упражнений базы работают на **Tier 1**. Tier 2 нужен для
> разделов Kubernetes (полная установка), IaC (Ansible по SSH) и Compute
> Platforms.

## Подразделы

1. [01_docker_compose](./01_docker_compose/) — установка Docker, базовые
   команды, compose quickstart; отсюда стартуют большинство стендов.
2. [02_local_vms](./02_local_vms/) — локальные VM по платформе:
   - `linux_kvm/` — KVM+QEMU+libvirt+Terraform (рекомендуемый Linux-сетап)
   - `macos_orbstack/` — OrbStack (macOS, включая Apple Silicon)
   - `windows_wsl2/` — WSL2 + Vagrant/VirtualBox или Multipass
3. [03_local_k8s](./03_local_k8s/) — локальный Kubernetes: kind (поверх Docker),
   k3d (k3s в Docker), minikube; когда что выбрать.
4. [04_cloud_vps](./04_cloud_vps/) — AWS Free Tier и Hetzner Cloud как
   дешёвые варианты Tier 3; Terraform для провижининга.
5. [05_capstone_project](./05_capstone_project/) — **финальный проект
   курса**: URL-shortener, который проводится через все разделы (Linux →
   контейнеры → Kubernetes → IaC → CI/CD → observability → SRE →
   security). Делается **в конце курса**, а не на шаге 0: каждый этап
   требует пройденного раздела, список — в README проекта.

## Принцип стендов

Стенд темы лежит рядом с её материалами:

```text
раздел/тема/02_examples/
├── docker-compose.yml   ← Tier 1: docker compose up -d
└── *.tf                 ← Tier 2/3: terraform init && terraform apply
```

`03_exercises/README.md` темы говорит, какой стенд поднять и на каком
тире. Terraform-стенды Tier 2 написаны под KVM/libvirt (Linux); на macOS и
Windows VM поднимаются средствами платформы (OrbStack, Vagrant,
Multipass) — см. [02_local_vms](./02_local_vms/).

## Когда двигаться дальше

- `docker compose up -d` поднимает стенд из
  [01_docker_compose](./01_docker_compose/02_examples/), и вы умеете его
  удалить.
- (Для Tier 2) можете поднять 1–3 локальные VM своей платформы и зайти на
  них по SSH.
- Можете создать и удалить локальный кластер kind/k3d.
- Дальше — [Раздел 1. Linux и shell](../1_linux_and_shell/). К
  [финальному проекту](./05_capstone_project/) возвращайтесь после
  разделов 1–10.
