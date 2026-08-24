# IaC Архитектурные паттерны

## Layered Stacks — разделение по слоям

```
Layer 0: Foundation (редко меняется)
  VPC, subnets, peering, DNS zones, IAM base roles
  State: s3://tfstate/foundation/terraform.tfstate

Layer 1: Platform (меняется иногда)
  EKS/RDS/ElastiCache/S3 buckets
  State: s3://tfstate/platform/terraform.tfstate
  Зависит от: Layer 0 outputs (через data source или remote state)

Layer 2: Services (меняется часто)
  k8s namespace конфигурация, IAM roles для сервисов
  State: s3://tfstate/services/${service}/terraform.tfstate

Layer 3: Application (меняется очень часто)
  Helm releases, ConfigMaps, feature flags
  Лучше через ArgoCD, не Terraform
```

```hcl
# Читать output из другого state (remote state)
data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket = "tfstate"
    key    = "foundation/terraform.tfstate"
    region = "eu-central-1"
  }
}

# Использовать output
resource "aws_eks_cluster" "this" {
  vpc_config {
    subnet_ids = data.terraform_remote_state.foundation.outputs.private_subnet_ids
  }
}
```

**Почему слои важны:**
- `terraform apply` в Layer 2 не может случайно сломать VPC
- Разные скорости изменений — разные blast radius
- Разные команды могут владеть разными слоями

## Immutable Infrastructure — не изменять, заменять

**Mutable (классический подход):**
```
Сервер → apt upgrade → изменить конфиг → перезапустить сервис
```
Проблема: конфигурационный drift, «а что на этом сервере вообще установлено?»

**Immutable:**
```
Создать новый образ (AMI/Docker image) → создать новые инстансы → переключить трафик → удалить старые
```

```hcl
# Launch Template — при изменении AMI создаёт НОВЫЕ инстансы, удаляет старые
resource "aws_launch_template" "app" {
  name_prefix   = "app-"
  image_id      = data.aws_ami.app.id   # новый AMI → новый Launch Template version
  instance_type = "t3.medium"

  lifecycle {
    create_before_destroy = true  # сначала новые, потом удалить старые
  }
}

resource "aws_autoscaling_group" "app" {
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }
}
```

## Drift Detection — обнаружение расхождений

**Drift** — когда реальная инфраструктура отличается от state (ручные изменения через консоль).

```bash
# Проверить drift без применения изменений
terraform plan -refresh-only

# В CI: запускать ежедневно
# Если есть drift → алерт/PR → объяснить или исправить

# GitHub Actions scheduled drift detection
on:
  schedule:
    - cron: '0 8 * * 1-5'  # каждый будний день в 08:00
jobs:
  drift-detection:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: terraform init
      - run: terraform plan -refresh-only -detailed-exitcode
        # exit code 2 = drift detected
```

## GitOps для инфраструктуры

```
Изменение в .tf файле
    │
    ▼ git push → PR
Code Review (terraform plan вывод в PR comment)
    │
    ▼ Merge в main
    │
    ▼ CI: terraform apply (автоматически или с approval)
    │
    ▼ State обновлён
```

```yaml
# GitLab CI — автоматический plan на MR, apply на main
.terraform-base:
  image: hashicorp/terraform:latest
  before_script:
    - terraform init

plan:
  extends: .terraform-base
  script:
    - terraform plan -out=tfplan -no-color > plan.txt
    - cat plan.txt
  artifacts:
    paths: [tfplan, plan.txt]
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'

apply:
  extends: .terraform-base
  script:
    - terraform apply -auto-approve tfplan
  dependencies: [plan]
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
      when: manual
```

## Module Registry — переиспользование

```hcl
# Публичный Terraform Registry
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
}

# Приватный registry через Git
module "vpc" {
  source = "git::https://gitlab.company.com/infra/tf-modules.git//vpc?ref=v2.1.0"
}

# Артефакт в S3 (для воздушно-изолированных окружений)
module "vpc" {
  source = "s3::https://s3.amazonaws.com/tf-modules/vpc/v2.1.0/module.zip"
}
```

## Secrets в IaC

```hcl
# НИКОГДА не хранить в .tf или state
variable "db_password" {
  sensitive = true  # скрывает из вывода plan/apply
  # получать из Vault, AWS SM или переменных окружения
}

# Vault provider
data "vault_generic_secret" "db" {
  path = "secret/production/database"
}

resource "aws_db_instance" "main" {
  password = data.vault_generic_secret.db.data["password"]
}

# AWS Secrets Manager
data "aws_secretsmanager_secret_version" "db" {
  secret_id = "production/database"
}

locals {
  db_creds = jsondecode(data.aws_secretsmanager_secret_version.db.secret_string)
}
```

## Тестирование IaC

```bash
# terraform validate — синтаксис и типы
terraform validate

# tflint — правила провайдеров (aws instance types, deprecated attrs)
tflint --init && tflint

# Checkov — security/compliance
checkov -d .

# Terratest (Go) — integration тесты
go test -v -timeout 30m ./test/...

# Pример Terratest теста
func TestVpc(t *testing.T) {
    opts := &terraform.Options{TerraformDir: "../modules/vpc"}
    defer terraform.Destroy(t, opts)
    terraform.InitAndApply(t, opts)
    vpcId := terraform.Output(t, opts, "vpc_id")
    assert.NotEmpty(t, vpcId)
}
```
