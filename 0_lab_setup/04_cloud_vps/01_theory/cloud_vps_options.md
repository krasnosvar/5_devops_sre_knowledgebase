# Облако и VPS — Tier-3 лаба

Tier-3 нужен когда:
- cloud-специфичная функциональность (IAM, managed k8s, S3)
- нужен внешний IP или DNS
- multi-node кластер с 16+ GB RAM (дорого держать локально)
- GPU для MLOps упражнений

## AWS Free Tier

12 месяцев после регистрации + always-free сервисы:

| Сервис | Free Tier |
|--------|-----------|
| EC2 t2.micro | 750 ч/мес (12 мес) |
| S3 | 5 GB хранилище |
| RDS db.t3.micro | 750 ч/мес (12 мес) |
| Lambda | 1 млн вызовов/мес (always-free) |
| CloudFront | 1 TB трафика/мес (12 мес) |

```bash
# AWS CLI установка
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip awscliv2.zip && sudo ./aws/install

# Конфигурация (IAM user с programmatic access)
aws configure
# или SSO:
aws configure sso

# Проверка
aws sts get-caller-identity
```

## Hetzner Cloud — дёшево для лаб

Немецкий провайдер, отличная цена. Подходит когда AWS Free Tier исчерпан.

| Тип | vCPU | RAM | Диск | Цена |
|-----|------|-----|------|------|
| CX22 | 2 (AMD) | 4 GB | 40 GB | ~€4/мес |
| CX32 | 4 (AMD) | 8 GB | 80 GB | ~€8/мес |
| CX42 | 8 (AMD) | 16 GB | 160 GB | ~€16/мес |
| CCX13 | 2 (dedicated) | 8 GB | 80 GB | ~€13/мес |

```bash
# hcloud CLI
brew install hcloud   # macOS
# или скачать с GitHub releases

hcloud context create my-project   # вставить API token
hcloud server list
hcloud server create \
  --name lab-node \
  --type cx22 \
  --image ubuntu-24.04 \
  --location fsn1 \
  --ssh-key ~/.ssh/lab_key.pub
hcloud server delete lab-node
```

```hcl
# Terraform Hetzner provider
terraform {
  required_providers {
    hcloud = { source = "hetznercloud/hcloud", version = "~> 1.47" }
  }
}

variable "hcloud_token" { sensitive = true }

provider "hcloud" { token = var.hcloud_token }

resource "hcloud_ssh_key" "lab" {
  name       = "lab-key"
  public_key = file("~/.ssh/lab_key.pub")
}

resource "hcloud_server" "lab" {
  count       = 3
  name        = "lab-node-${count.index + 1}"
  server_type = "cx22"
  image       = "ubuntu-24.04"
  location    = "fsn1"
  ssh_keys    = [hcloud_ssh_key.lab.id]
}

output "ips" { value = hcloud_server.lab[*].ipv4_address }
```

```bash
terraform init
terraform apply -var="hcloud_token=YOUR_TOKEN"
# поработать с нодами...
terraform destroy   # удалить и перестать платить
```

## DigitalOcean Droplets

```bash
# doctl — CLI DigitalOcean
brew install doctl
doctl auth init   # вставить API token

doctl compute droplet create lab-node \
  --region fra1 \
  --size s-2vcpu-4gb \
  --image ubuntu-24-04-x64 \
  --ssh-keys YOUR_KEY_ID

doctl compute droplet list
doctl compute droplet delete lab-node
```

## GPU по часам — для MLOps

| Провайдер | GPU | Цена | Особенности |
|-----------|-----|------|-------------|
| [RunPod](https://runpod.io) | RTX 4090 24GB | ~$0.74/ч | Community cloud, дёшево, быстрый старт |
| [Lambda Labs](https://lambdalabs.com) | H100 80GB | ~$2.5/ч | Надёжнее RunPod, дешевле AWS |
| [Vast.ai](https://vast.ai) | RTX 3090/4090 | от $0.3/ч | Маркетплейс частных серверов |
| [Paperspace](https://www.paperspace.com) | A100 40GB | ~$3.09/ч | Хорошая документация |
| AWS p3.2xlarge | V100 16GB | ~$3.06/ч | Managed, но дорого |

```bash
# Типичный workflow на RunPod:
# 1. Создать Pod с нужным GPU
# 2. Подключиться по SSH
# 3. Запустить обучение/инференс
# 4. Сохранить результаты в облачное хранилище
# 5. Удалить Pod (оплата прекращается)

# ВАЖНО: всегда удаляй GPU инстансы после работы
# $0.74/ч × 24ч = ~$18/день если забыть удалить
```

## Правила экономии

```bash
# 1. Удалять инфраструктуру после упражнения
terraform destroy -auto-approve

# 2. Использовать Spot/Preemptible для batch задач
# AWS Spot: до 90% дешевле (могут прервать с 2 мин предупреждением)

# 3. Для разработки — остановить, не удалять
# Stopped EC2 не платит за compute (только за EBS ~$0.10/GB/мес)

# 4. Budget alerts в AWS
aws budgets create-budget \
  --account-id 123456789 \
  --budget file://budget.json \
  --notifications-with-subscribers file://notifications.json
# Уведомление когда расходы > $10

# 5. aws-nuke / cloud-nuke — удалить всё в регионе (осторожно!)
# Для очистки тестовых аккаунтов
```
