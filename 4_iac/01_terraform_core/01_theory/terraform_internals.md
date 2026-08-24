# Terraform — как работает изнутри

## State — сердце Terraform

State (`terraform.tfstate`) — JSON файл, который хранит соответствие
между ресурсами в конфигурации и реальными объектами в инфраструктуре.

**Что хранит state:**
- resource ID в провайдере (например: `i-0abc123` для EC2)
- все атрибуты ресурса на момент последнего apply
- зависимости между ресурсами

**Зачем нужен:**
- `plan` сравнивает state с конфигурацией → показывает diff
- `apply` обновляет state после создания/изменения ресурсов
- `destroy` знает что удалять из state

```bash
# посмотреть state
terraform state list
terraform state show aws_instance.web

# state как JSON
terraform show -json | jq '.values.root_module.resources[]'
```

## Граф зависимостей

Terraform строит DAG (directed acyclic graph) зависимостей:

```hcl
resource "aws_vpc" "main" { ... }

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id     # зависит от vpc
}

resource "aws_instance" "web" {
  subnet_id = aws_subnet.public.id  # зависит от subnet
}
```

Terraform создаёт в правильном порядке, удаляет в обратном.
Независимые ресурсы создаются параллельно.

```bash
terraform graph | dot -Tsvg > graph.svg   # visualize (requires graphviz)
```

## Plan — что произойдёт

```bash
terraform plan              # показать изменения
terraform plan -out=tfplan  # сохранить план в файл

# Символы в выводе plan:
# + create
# ~ update in-place
# - destroy
# -/+ destroy and recreate (если изменить immutable атрибут)
# <= data source read

# Посмотреть что именно изменится в ресурсе
terraform plan -out=p && terraform show -json p | jq '
  .resource_changes[] |
  select(.change.actions[] | . != "no-op") |
  {resource: .address, actions: .change.actions}
'
```

## Apply lifecycle

```
1. Lock state (backend) — предотвратить параллельный apply
2. Refresh — опционально обновить state из реальной инфраструктуры
3. Plan — сравнить желаемое (config) с текущим (state)
4. Confirm — показать план, ждать подтверждения (или -auto-approve)
5. Apply — создать/изменить/удалить ресурсы через провайдер API
6. Update state — записать новое состояние
7. Unlock state
```

**Если apply упал на середине:** state может быть в частичном состоянии.
Решение: исправить проблему → `terraform apply` снова (идемпотентно).

## Refresh-only — обнаружение drift

```bash
# показать drift между state и реальной инфраструктурой
# НЕ вносит изменений
terraform plan -refresh-only

# обновить state под реальность (осторожно!)
terraform apply -refresh-only
```

## Remote backends и locking

```hcl
# S3 backend с DynamoDB локом
terraform {
  backend "s3" {
    bucket         = "my-tfstate-prod"
    key            = "network/terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
    dynamodb_table = "terraform-state-locks"
  }
}
```

**DynamoDB lock:** при `terraform apply` записывается lock запись.
Второй `terraform apply` видит lock → ждёт или падает с ошибкой.
При аварийном завершении lock остаётся → `terraform force-unlock LOCK_ID`.

## Partial backend config (секреты не в коде)

```bash
# backend.hcl (не коммитить)
access_key = "AKIAIOSFODNN7EXAMPLE"
secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

terraform init -backend-config=backend.hcl
```

## import — принять существующие ресурсы под управление TF

```bash
# 1. написать resource block в .tf
# 2. импортировать
terraform import aws_s3_bucket.legacy my-bucket-name
terraform import 'aws_instance.web[0]' i-0abc123

# Terraform 1.5+: import block в конфигурации (preferred)
import {
  to = aws_s3_bucket.legacy
  id = "my-bucket-name"
}
# terraform plan покажет diff, apply выполнит import
```

## Почему ресурс пересоздаётся (destroy + create)

Некоторые атрибуты immutable в API провайдера — их нельзя изменить,
только пересоздать ресурс:

```
-/+ resource "aws_instance" "web" {
      ~ ami = "ami-old" -> "ami-new"   # requires replacement!
    }
```

Как контролировать:
```hcl
lifecycle {
  create_before_destroy = true   # сначала создать, потом удалить (zero-downtime)
  prevent_destroy = true         # не разрешать destroy (защита prod БД)
  ignore_changes = [tags]        # игнорировать изменения тегов (если задаются снаружи)
}
```
