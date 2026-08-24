# Terraform модули

## Зачем нужны модули

Модуль — переиспользуемый набор ресурсов с параметрами.
Без модулей: копируешь один и тот же код VPC в каждый окружение.
С модулями: `module "vpc" { source = "./modules/vpc" }` в каждом окружении.

## Структура модуля

```
modules/vpc/
├── main.tf        ← ресурсы
├── variables.tf   ← входные параметры
├── outputs.tf     ← выходные значения
├── versions.tf    ← требования к провайдерам
└── README.md      ← terraform-docs генерирует автоматически
```

```hcl
# modules/vpc/variables.tf
variable "name" {
  description = "VPC name prefix"
  type        = string
}

variable "cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.cidr, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "azs" {
  description = "Availability zones"
  type        = list(string)
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
```

```hcl
# modules/vpc/main.tf
locals {
  common_tags = merge(var.tags, {
    Module = "vpc"
    Name   = var.name
  })
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = merge(local.common_tags, { Name = var.name })
}

resource "aws_subnet" "public" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.cidr, 8, count.index)
  availability_zone = var.azs[count.index]
  map_public_ip_on_launch = true
  tags = merge(local.common_tags, {
    Name = "${var.name}-public-${var.azs[count.index]}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.cidr, 8, count.index + 10)
  availability_zone = var.azs[count.index]
  tags = merge(local.common_tags, {
    Name = "${var.name}-private-${var.azs[count.index]}"
    Tier = "private"
  })
}
```

```hcl
# modules/vpc/outputs.tf
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}
```

## Использование модуля

```hcl
# environments/production/main.tf

# Локальный модуль
module "vpc" {
  source = "../../modules/vpc"

  name = "prod"
  cidr = "10.0.0.0/16"
  azs  = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  tags = { Environment = "production" }
}

# Использовать вывод модуля
module "eks" {
  source = "../../modules/eks"

  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
}

# Модуль из Terraform Registry
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "prod-cluster"
  cluster_version = "1.29"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
}

# Модуль из Git
module "my_module" {
  source = "git::https://github.com/org/tf-modules.git//vpc?ref=v2.1.0"
}
```

## for_each в модулях

```hcl
# создать несколько S3 bucket'ов через один модуль
locals {
  buckets = {
    assets   = { versioning = true,  lifecycle_days = 365 }
    backups  = { versioning = true,  lifecycle_days = 90  }
    logs     = { versioning = false, lifecycle_days = 30  }
  }
}

module "s3_buckets" {
  for_each = local.buckets
  source   = "./modules/s3"

  name           = "${var.environment}-${each.key}"
  versioning     = each.value.versioning
  lifecycle_days = each.value.lifecycle_days
}

# обратиться к конкретному bucket
output "assets_bucket" {
  value = module.s3_buckets["assets"].bucket_id
}
```

## Версионирование модулей

```hcl
# Правило: всегда пиновать версию модуля
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"   # минорные обновления OK, major — нет
  # Не делать: version = ">= 1.0"  ← сломается при major release
}

# Для Git: использовать теги, не ветки
module "vpc" {
  source = "git::https://github.com/org/tf-modules.git//vpc?ref=v2.1.0"
  # Не делать: ?ref=main  ← непредсказуемо
}
```

## terraform-docs — автогенерация README

```bash
# установка
brew install terraform-docs

# генерировать README из комментариев и типов переменных
terraform-docs markdown ./modules/vpc > modules/vpc/README.md

# в pre-commit hook
repos:
  - repo: https://github.com/terraform-docs/gh-actions
    hooks:
      - id: terraform-docs-system
        args: ["--output-file", "README.md", "--output-mode", "inject"]
```
