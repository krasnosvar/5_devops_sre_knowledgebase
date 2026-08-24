# Tier 3 — Cloud / VPS

Когда нужна реальная внешняя инфраструктура: публичный IP, managed services,
multi-region, или просто мощная машина с GPU.

## AWS Free Tier

12 месяцев бесплатно после регистрации:
- **EC2**: t2.micro (1 vCPU, 1 GB RAM) — 750 ч/мес
- **S3**: 5 GB
- **RDS**: db.t3.micro — 750 ч/мес
- **EKS**: кластер бесплатен, платишь за worker nodes (EC2)

```bash
# установить AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip awscliv2.zip && sudo ./aws/install

# настроить credentials
aws configure   # или: aws configure sso

# проверить
aws sts get-caller-identity
```

## Hetzner Cloud — дешевле AWS для лаб

Немецкий провайдер, отличное соотношение цена/производительность.

| Тип | vCPU | RAM | Цена |
|-----|------|-----|------|
| CX22 | 2 | 4 GB | ~€4/мес |
| CX32 | 4 | 8 GB | ~€8/мес |
| CX42 | 8 | 16 GB | ~€16/мес |

```bash
# hcloud CLI
# https://github.com/hetznercloud/cli

hcloud server create \
  --name lab-node \
  --type cx22 \
  --image ubuntu-24.04 \
  --location fsn1 \
  --ssh-key ~/.ssh/lab_key.pub

hcloud server list
hcloud server delete lab-node
```

```hcl
# Terraform Hetzner provider
terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.47"
    }
  }
}

variable "hcloud_token" {}

provider "hcloud" {
  token = var.hcloud_token
}

resource "hcloud_server" "lab" {
  count       = 2
  name        = "lab-node-${count.index + 1}"
  server_type = "cx22"
  image       = "ubuntu-24.04"
  location    = "fsn1"
  ssh_keys    = [hcloud_ssh_key.lab.id]
}

resource "hcloud_ssh_key" "lab" {
  name       = "lab-key"
  public_key = file("~/.ssh/lab_key.pub")
}
```

## RunPod / Lambda Labs — GPU по часам

Для упражнений по MLOps когда нужна GPU:

| Провайдер | GPU | Цена | Особенности |
|-----------|-----|------|-------------|
| [RunPod](https://runpod.io) | RTX 4090 | ~$0.74/ч | Community cloud, дёшево |
| [Lambda Labs](https://lambdalabs.com) | H100 | ~$2.5/ч | Дешевле AWS, надёжно |
| [Vast.ai](https://vast.ai) | разные | от $0.2/ч | Маркетплейс, самые низкие цены |

> Для большинства MLOps упражнений хватает RunPod с RTX 3090/4090 (~$0.4–0.7/ч).
> Удаляй инстанс сразу после упражнения — оплата посекундная.
