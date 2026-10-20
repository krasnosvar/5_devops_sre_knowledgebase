# 04. Tier 3 — Cloud / VPS

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — быстрый
> справочник команд, флагов и типовых конфигов.

## Зачем

Когда нужна реальная внешняя инфраструктура: публичный IP и DNS, managed
services (IAM, S3, managed k8s), многоузловой стенд с RAM больше, чем есть
локально, или GPU. Здесь — как получить такой стенд дёшево и не забыть его
удалить.

## Пререквизиты

- [02_local_vms](../02_local_vms/) — SSH-ключ `~/.ssh/lab_key` и опыт
  работы с VM.
- Аккаунт у провайдера и привязанная карта (даже для бесплатных лимитов).

> **Забегание вперёд.** Здесь используется Terraform, который подробно
> разбирается в [5_iac/01_terraform_core](../../5_iac/01_terraform_core/).
> Для этой темы достаточно: `terraform init`, `terraform plan`,
> `terraform apply`, `terraform destroy`. Если Terraform ещё не освоен —
> серверы можно создать через `hcloud`/`doctl` CLI или веб-консоль.

> **Забегание вперёд.** AWS CLI и сам AWS подробно разбираются в
> [7_compute_platforms/02_aws](../../7_compute_platforms/02_aws/). Для этой
> темы достаточно: `aws configure` и `aws sts get-caller-identity`.

## Файлы

- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: AWS CLI, hcloud, doctl, цены и
  экономия.
- [01_theory/cloud_vps_options.md](01_theory/cloud_vps_options.md) — AWS,
  Hetzner, DigitalOcean, GPU-провайдеры, правила экономии.
- [02_examples/hetzner.tf](02_examples/hetzner.tf) — 3 ноды на Hetzner
  Cloud с приватной сетью.
- Без `03_exercises/`: без лабы — требует реальное облако и оплату;
  облачные упражнения — в [7_compute_platforms](../../7_compute_platforms/).

## Как проходить

1. Прочитать теорию, выбрать провайдера.
2. Настроить budget alert до создания первого ресурса.
3. Поднять `hetzner.tf` (`plan` → `apply`), зайти по SSH, удалить
   (`destroy`) в тот же день.

## AWS Free Tier

Условия Free Tier менялись: с 15 июля 2025 года новые аккаунты получают
стартовые кредиты и бесплатный план, ограниченный по сроку, вместо
прежней модели «12 месяцев бесплатно» (она осталась у аккаунтов,
созданных раньше). Актуальные лимиты — только на
https://aws.amazon.com/free/.

- **EC2, S3, RDS** — укладываются в кредиты/лимиты Free Tier при малых
  инстансах; проверяйте лимиты на странице выше.
- **EKS** — control plane платный: $0.10/ч за кластер (~$73/мес) плюс
  worker nodes (EC2). Для лаб по k8s дешевле kind/k3d или VPS.

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

> Линейка типов и цены у Hetzner периодически меняются — перед запуском
> сверьтесь с актуальным прайсом и при необходимости поменяйте `server_type`.

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

## Когда двигаться дальше

- Настроен budget alert, и вы знаете, где посмотреть текущие расходы.
- Можете поднять облачный стенд через `terraform plan`/`apply` и удалить
  его через `terraform destroy`, не оставив ресурсов.
- Знаете, какие облачные сервисы платные даже «на старте» (например,
  control plane EKS).
- Дальше — раздел [1_linux_and_shell](../../1_linux_and_shell/);
  [05_capstone_project](../05_capstone_project/) проходится в конце курса.
