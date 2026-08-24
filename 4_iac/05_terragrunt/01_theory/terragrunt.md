# Terragrunt — DRY для Terraform

## Проблема которую решает Terragrunt

В Terraform каждый environment нужно повторять backend конфиг:

```
environments/
├── dev/
│   ├── main.tf
│   └── backend.tf      ← backend "s3" { bucket="..." key="dev/..." }
├── staging/
│   ├── main.tf
│   └── backend.tf      ← backend "s3" { bucket="..." key="staging/..." }
└── production/
    ├── main.tf
    └── backend.tf      ← backend "s3" { bucket="..." key="production/..." }
```

Terragrunt решает это через иерархический `terragrunt.hcl`.

## Структура проекта с Terragrunt

```
infrastructure/
├── terragrunt.hcl          ← корневой: общий backend, провайдеры
├── _common/
│   └── vpc.hcl             ← общие переменные
├── dev/
│   ├── terragrunt.hcl      ← inherit root + dev-специфика
│   ├── vpc/
│   │   └── terragrunt.hcl  ← конкретный стек
│   └── eks/
│       └── terragrunt.hcl
└── production/
    ├── terragrunt.hcl
    ├── vpc/
    │   └── terragrunt.hcl
    └── eks/
        └── terragrunt.hcl
```

## Корневой terragrunt.hcl

```hcl
# infrastructure/terragrunt.hcl

locals {
  account_id = get_aws_account_id()
  region     = "eu-central-1"

  # парсить путь для определения environment
  path_components = split("/", path_relative_to_include())
  environment     = path_components[0]   # dev / staging / production
}

# Общий remote state backend — ключ генерируется из пути
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "my-tfstate-${local.account_id}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.region
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

# Общие входные переменные для всех модулей
inputs = {
  aws_region  = local.region
  environment = local.environment
  account_id  = local.account_id
}

# Общие теги через generate
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.region}"
  default_tags {
    tags = {
      Environment = "${local.environment}"
      ManagedBy   = "Terraform"
    }
  }
}
EOF
}
```

## Стек-уровневый terragrunt.hcl

```hcl
# infrastructure/production/eks/terragrunt.hcl

include "root" {
  path = find_in_parent_folders()   # найти корневой terragrunt.hcl
}

# зависимость от VPC — Terragrunt прочитает output
dependency "vpc" {
  config_path = "../vpc"

  # мок-данные для plan без деплоя VPC
  mock_outputs = {
    vpc_id          = "vpc-mock"
    private_subnet_ids = ["subnet-mock-1", "subnet-mock-2"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# какой Terraform модуль использовать
terraform {
  source = "tfr:///terraform-aws-modules/eks/aws?version=20.8.0"
}

inputs = {
  cluster_name    = "prod-cluster"
  cluster_version = "1.29"
  vpc_id          = dependency.vpc.outputs.vpc_id
  subnet_ids      = dependency.vpc.outputs.private_subnet_ids

  eks_managed_node_groups = {
    general = {
      instance_types = ["m5.large"]
      min_size       = 2
      max_size       = 10
      desired_size   = 3
    }
  }
}
```

## Команды Terragrunt

```bash
# применить один стек
cd infrastructure/production/eks
terragrunt apply

# применить все стеки в директории (учитывая зависимости)
cd infrastructure/production
terragrunt run-all apply

# plan без применения
terragrunt run-all plan

# только изменённые стеки (отслеживает output)
terragrunt run-all apply --terragrunt-include-dir "*/vpc" --terragrunt-include-dir "*/eks"

# граф зависимостей
terragrunt graph-dependencies | dot -Tsvg > deps.svg

# уничтожить в правильном порядке (reverse dependency order)
terragrunt run-all destroy
```

## Когда Terragrunt, когда нет

**Использовать Terragrunt** если:
- 3+ окружений с одинаковой структурой
- Нужна автоматическая зависимость между стеками (VPC → EKS → Apps)
- Хочется DRY backend конфига

**Не использовать** если:
- 1-2 окружения — лишняя сложность
- Команда незнакома с Terragrunt — кривая обучения
- Используется Terraform Cloud/Enterprise — там есть workspace для multi-env
