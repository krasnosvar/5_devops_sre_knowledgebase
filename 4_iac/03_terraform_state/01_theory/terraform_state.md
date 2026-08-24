# Terraform State — управление состоянием

## Что хранит state и почему это важно

State — единственный источник правды о том, что Terraform считает созданным.
Без state Terraform не знает какие ресурсы ему принадлежат.

```json
// terraform.tfstate (упрощённо)
{
  "version": 4,
  "resources": [
    {
      "type": "aws_instance",
      "name": "web",
      "provider": "provider[\"registry.terraform.io/hashicorp/aws\"]",
      "instances": [{
        "attributes": {
          "id": "i-0abc123def456",
          "ami": "ami-0c7af5f9",
          "instance_type": "t3.micro",
          "public_ip": "3.64.12.45"
          // ... все атрибуты
        }
      }]
    }
  ]
}
```

**Чего нельзя делать со state:**
- Хранить в git (содержит чувствительные данные, конфликты при параллельной работе)
- Редактировать вручную (использовать `terraform state` команды)
- Удалять без понимания последствий

## Backends — где хранить state

### Локальный (по умолчанию)
Хранится в `terraform.tfstate` в текущей директории.
Подходит только для экспериментов, не для команды.

### S3 + DynamoDB (рекомендуется для AWS)

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-prod"
    key            = "services/api/terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true                      # server-side encryption
    dynamodb_table = "terraform-state-locks"   # distributed lock
    
    # Версионирование bucket'а — можно вернуться к предыдущему state
    # aws s3api put-bucket-versioning --bucket my-terraform-state-prod --versioning-configuration Status=Enabled
  }
}
```

```bash
# Создать инфраструктуру для state (один раз, вручную или bootstrap скриптом)
aws s3api create-bucket --bucket my-terraform-state-prod --region eu-central-1 \
  --create-bucket-configuration LocationConstraint=eu-central-1

aws s3api put-bucket-versioning --bucket my-terraform-state-prod \
  --versioning-configuration Status=Enabled

aws dynamodb create-table --table-name terraform-state-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### Partial backend config (секреты не в коде)

```bash
# backend.hcl (не коммитить, хранить в секретах CI)
bucket         = "my-terraform-state-prod"
dynamodb_table = "terraform-state-locks"

# Инициализация с внешним конфигом
terraform init -backend-config=backend.hcl
# или по флагам:
terraform init -backend-config="bucket=my-state" -backend-config="region=eu-central-1"
```

## State Lock — защита от параллельных apply

Когда `terraform apply` запускается, backend захватывает lock в DynamoDB.
Второй `terraform apply` видит lock и ждёт или падает с ошибкой.

```bash
# Посмотреть активный lock
aws dynamodb get-item --table-name terraform-state-locks \
  --key '{"LockID": {"S": "my-bucket/services/api/terraform.tfstate"}}'

# Принудительно снять lock (после аварийного завершения)
terraform force-unlock LOCK_ID

# LOCK_ID берётся из сообщения об ошибке или из DynamoDB
```

## Операции с state

```bash
# Список всех ресурсов
terraform state list
terraform state list 'module.vpc.*'

# Показать атрибуты ресурса
terraform state show aws_instance.web
terraform state show 'module.eks.aws_eks_cluster.this[0]'

# Переместить ресурс (переименование без пересоздания)
terraform state mv aws_instance.old aws_instance.new
terraform state mv 'module.old.aws_s3_bucket.data' 'module.new.aws_s3_bucket.data'

# Удалить из state (ресурс останется в AWS, но Terraform забудет о нём)
terraform state rm aws_instance.temp
terraform state rm 'module.vpc.aws_subnet.public[2]'

# Bulk delete (например, убрать весь модуль из state)
terraform state list | grep 'module.legacy' | xargs -I{} terraform state rm '{}'

# Скачать state (для ручного анализа)
terraform state pull > current-state.json

# Загрузить изменённый state (ОПАСНО, только если точно знаешь что делаешь)
terraform state push terraform.tfstate
```

## Миграция между backends

```bash
# Переехать с local на S3
# 1. Добавить backend "s3" в main.tf
# 2. Запустить init с migrate-state
terraform init -migrate-state

# Terraform спросит: "Do you want to copy existing state to the new backend?"
# Ответить: yes

# Переехать между S3 bucket'ами
# 1. Изменить bucket в backend конфиге
terraform init -migrate-state
```

## Разбиение state (State isolation)

**Проблема одного большого state:**
- Один `terraform apply` может затронуть всю инфраструктуру
- Медленный refresh (обновление состояния всех ресурсов)
- Риск: ошибка в конфиге одного сервиса → потенциальный blast radius на всё

**Стратегии изоляции:**

**По слоям:**
```
state/
├── network/    # VPC, subnets — редко меняется
├── database/   # RDS, ElastiCache — иногда меняется
├── compute/    # EKS, ASG — часто меняется
└── apps/       # конфиги приложений — очень часто
```

**По окружениям (Terraform workspaces):**
```bash
terraform workspace new staging
terraform workspace select production
# разные state для разных workspace
```

**По окружениям (разные директории):**
```
environments/
├── dev/        # отдельный state
├── staging/    # отдельный state
└── production/ # отдельный state
```

## Аварийное восстановление state

```bash
# S3 versioning позволяет вернуться к предыдущему state
aws s3api list-object-versions \
  --bucket my-terraform-state-prod \
  --prefix services/api/terraform.tfstate

# Восстановить конкретную версию
aws s3api get-object \
  --bucket my-terraform-state-prod \
  --key services/api/terraform.tfstate \
  --version-id VERSION_ID \
  terraform.tfstate.backup

# Применить восстановленный state
terraform state push terraform.tfstate.backup
```
