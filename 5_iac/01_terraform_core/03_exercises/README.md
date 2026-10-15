# Упражнения — Terraform core

Тир: 🐳 Tier 1 (Docker provider) или 🖥 Tier 2 (libvirt/VirtualBox)

## 01 — Первый apply с Docker provider

**Задача:** Написать конфигурацию, которая создаёт nginx-контейнер
через Terraform Docker provider.

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

**Задача:** Параметризовать конфигурацию из упражнения 01. Принимать
на вход: image, port, container name. Выводить: container ID, URL.

## 03 — State management

**Задача:**
1. Создать ресурс через Terraform (конфигурация из упражнения 01).
2. Удалить контейнер вручную (`docker rm -f ...`).
3. Запустить `terraform plan` — убедиться, что Terraform обнаружил drift.
4. Выполнить `terraform apply -refresh-only` — убрать удалённый
   контейнер из state, ничего не создавая.
5. Вручную (`docker run`) создать контейнер с тем же именем и добавить
   его в state через `terraform import` (или блок `import {}`); затем
   посмотреть, что покажет `terraform plan` после импорта.

## 04 — Remote state в локальном S3 (без AWS-аккаунта)

**Задача:** Хранить state в S3-совместимом хранилище, запущенном
локально в Docker, с блокировкой через `use_lockfile = true`
(Terraform 1.10+). DynamoDB для блокировок больше не нужна: этот способ
в S3 backend помечен как deprecated.

> **Забегание вперёд.** Здесь используется AWS CLI, который подробно
> разбирается в [7_compute_platforms/02_aws](../../../7_compute_platforms/02_aws/).
> Для этой темы достаточно: `aws --endpoint-url=... s3 mb/ls` и
> переменные `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` (здесь —
> фиктивные `test`/`test`, реального AWS-аккаунта не нужно). Если AWS
> CLI ещё не освоен — упражнение можно пропустить и вернуться к нему
> позже.

```bash
# Локальный S3: SeaweedFS (тег зафиксирован, а не latest)
docker run -d --name tf-s3 -p 8333:8333 chrislusf/seaweedfs:4.48 server -s3

# Фиктивные ключи: SeaweedFS без настроенных пользователей их не проверяет
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

aws --endpoint-url=http://localhost:8333 s3 mb s3://terraform-state

# Настроить backend "s3" (endpoint, use_path_style, use_lockfile)
```

Проверить блокировку: пока в одном терминале висит `terraform apply`
(ждёт ответа `yes`), во втором запустить `terraform plan`.

> Почему не LocalStack/MinIO: с марта 2026 образ LocalStack требует
> auth token (бесплатный план есть, но нужна регистрация), а MinIO
> перестал публиковать community-образы. Если у вас уже есть один из
> них — подойдёт и он, меняется только endpoint.

## 05 — Workspaces

**Задача:** Создать два workspace (dev, prod) с разными параметрами
(dev: 1 реплика, prod: 3). Оба окружения должны существовать
одновременно на одном Docker-хосте.
