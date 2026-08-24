# Упражнения — Terraform core

Тир: 🐳 Tier 1 (Docker provider) или 🖥 Tier 2 (libvirt/VirtualBox)

## 01 — Первый apply с Docker provider

**Задача:** Написать конфигурацию которая создаёт nginx контейнер через Terraform Docker provider.

```hcl
# TODO: main.tf
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# resource "docker_image" ...
# resource "docker_container" ...
```

```bash
terraform init
terraform plan
terraform apply
curl http://localhost:8080
terraform destroy
```

## 02 — Variables и outputs

**Задача:** Параметризовать конфигурацию из упражнения 01. Принимать на вход: image, port, container name. Выводить: container ID, URL.

## 03 — State management

**Задача:**
1. Создать ресурс через Terraform
2. Удалить его вручную (docker rm ...)
3. Запустить terraform plan — убедиться что обнаружил drift
4. Выполнить terraform apply -refresh-only
5. Выполнить terraform import для добавления существующего контейнера в state

## 04 — Remote state (S3 + DynamoDB local)

**Задача:** Настроить remote state через LocalStack (AWS эмулятор) или MinIO.

```bash
# Запустить LocalStack
docker run -d -p 4566:4566 localstack/localstack

# Создать S3 bucket и DynamoDB таблицу через aws cli
aws --endpoint-url=http://localhost:4566 s3 mb s3://terraform-state
aws --endpoint-url=http://localhost:4566 dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

# Настроить backend в main.tf
```

## 05 — Workspaces

**Задача:** Создать два workspace (dev, prod) с разными параметрами (dev: 1 replica, prod: 3).
