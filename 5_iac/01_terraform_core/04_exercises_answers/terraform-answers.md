# Ответы — Terraform core

Все команды выполняются вручную, по одной, с чтением вывода. Никаких
`-auto-approve`: перед каждым `apply` смотрим `plan`, на вопрос
`Enter a value:` отвечаем `yes` только после проверки плана.

Файлы ответов:
- упражнение 01 — [../02_examples/main.tf](../02_examples/main.tf);
- упражнение 02 — [ex02_variables/main.tf](./ex02_variables/main.tf);
- упражнение 04 — [ex04_remote_state/backend.tf](./ex04_remote_state/backend.tf);
- упражнение 05 — [ex05_workspaces/main.tf](./ex05_workspaces/main.tf).

Если порт 8080 на машине занят, добавляйте `-var="nginx_port=18080"`
ко всем `plan`/`apply`/`destroy` и `curl` на тот же порт.

## Упражнение 01 — Первый apply с Docker provider

```bash
cd 5_iac/01_terraform_core/02_examples/
terraform init
terraform plan -out=tfplan
terraform apply tfplan
curl http://localhost:8080
terraform destroy
```

Ожидаемый вывод (примерно так):

```text
Plan: 3 to add, 0 to change, 0 to destroy.
Saved the plan to: tfplan
...
Apply complete! Resources: 3 added, 0 changed, 0 destroyed.
Outputs:
container_id = "613cb511d6e9..."
nginx_url = "http://localhost:8080"

<h1>Hello from Terraform + Docker!</h1><p>Container: lab-app</p>

Plan: 0 to add, 0 to change, 3 to destroy.
Do you really want to destroy all resources?
  Enter a value: yes
Destroy complete! Resources: 3 destroyed.
```

Почему так: `plan -out=tfplan` сохраняет именно тот план, который вы
прочитали, а `apply tfplan` применяет его без повторного планирования и
без вопроса — сюрпризов между plan и apply нет. `destroy` показывает
свой план и требует `yes`.

## Упражнение 02 — Variables и outputs

```bash
cd 5_iac/01_terraform_core/04_exercises_answers/ex02_variables/
terraform init
terraform plan -out=tfplan \
  -var="image=nginx:alpine" -var="port=8090" -var="container_name=my-lab"
terraform apply tfplan
terraform output
curl "$(terraform output -raw url)"
terraform destroy \
  -var="image=nginx:alpine" -var="port=8090" -var="container_name=my-lab"
```

Ожидаемый вывод (примерно так):

```text
Plan: 2 to add, 0 to change, 0 to destroy.
...
container_id = "d9e938f48f19..."
url = "http://localhost:8090"

<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
Destroy complete! Resources: 2 destroyed.
```

Почему так: у переменных нет `default`, поэтому без `-var` Terraform
спросит значение (или с `-input=false` упадёт с
`No value for required variable`) — забытый параметр не подменяется
молча. `destroy` тоже требует те же `-var`: конфигурация вычисляется
заново. Удобнее положить значения в `terraform.tfvars`.

## Упражнение 03 — State management

Работаем в `02_examples/` из упражнения 01 (`app_name` по умолчанию
`lab-app`, контейнер называется `lab-app-nginx`).

```bash
cd 5_iac/01_terraform_core/02_examples/
terraform plan -out=tfplan
terraform apply tfplan

# 2. Ручное удаление — это и есть drift
docker rm -f lab-app-nginx

# 3. Обычный plan видит, что объекта нет, и хочет создать заново
terraform plan

# 4. Синхронизировать state с реальностью, ничего не создавая
terraform apply -refresh-only
terraform state list
```

Ожидаемый вывод (примерно так):

```text
Note: Objects have changed outside of Terraform
  # docker_container.nginx has been deleted
...
  # docker_container.nginx will be created
Plan: 1 to add, 0 to change, 0 to destroy.

(apply -refresh-only, после ответа yes)
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

docker_image.nginx
docker_network.app_net
```

Теперь `docker_container.nginx` в state нет, и его можно
импортировать. Импортировать адрес, который уже есть в state, нельзя:
Terraform ответит `Resource already managed by Terraform`.

```bash
# 5. Контейнер, созданный "мимо" Terraform
docker run -d --name lab-app-nginx --network lab-app-network \
  -p 8080:80 nginx:alpine

# Docker provider импортирует контейнер по полному ID, а не по имени
terraform import docker_container.nginx \
  "$(docker inspect -f '{{.Id}}' lab-app-nginx)"

terraform plan
```

Ожидаемый вывод (примерно так):

```text
Import successful!
...
  # docker_container.nginx must be replaced
      ~ image        = "nginx:alpine" -> "sha256:3dd0..." # forces replacement
      + labels { # forces replacement
      + upload { # forces replacement
Plan: 1 to add, 0 to change, 1 to destroy.
```

Вариант без CLI-команды (Terraform 1.5+) — блок `import` в `.tf`; он
проходит через обычный `plan`, поэтому его видно на ревью:

```hcl
import {
  to = docker_container.nginx
  id = "<полный ID из docker inspect>"
}
```

```bash
terraform plan    # покажет: 1 to import, ...
```

После импорта блок `import` удаляют из кода. Завершение упражнения:

```bash
terraform plan -out=tfplan   # замена контейнера на "правильный"
terraform apply tfplan
terraform destroy
```

Почему так: import только записывает существующий объект в state, он
не меняет код. Ручной контейнер отличается от описания (нет `upload`,
`labels`, другой `image`), и у Docker-контейнера эти атрибуты нельзя
поменять на месте — поэтому план после импорта предлагает замену.
Правильный импорт — когда после него `plan` показывает
`No changes` или осознанные изменения.

## Упражнение 04 — Remote state в локальном S3 (без AWS-аккаунта)

```bash
# Локальный S3
docker run -d --name tf-s3 -p 8333:8333 chrislusf/seaweedfs:4.48 server -s3
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
aws --endpoint-url=http://localhost:8333 s3 mb s3://terraform-state

# Конфигурация: main.tf из примера + backend.tf из ответа
mkdir -p ~/tf-remote-state && cd ~/tf-remote-state
TOPIC=<путь к репо>/5_iac/01_terraform_core
cp "$TOPIC/02_examples/main.tf" .
cp "$TOPIC/04_exercises_answers/ex04_remote_state/backend.tf" .

terraform init
terraform plan -out=tfplan
terraform apply tfplan
aws --endpoint-url=http://localhost:8333 s3 ls s3://terraform-state --recursive
```

Ожидаемый вывод (примерно так):

```text
Successfully configured the backend "s3"! Terraform will automatically
use this backend unless the backend configuration changes.
...
Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

2026-10-14 20:57:16       7008 lab/terraform.tfstate
```

Проверка блокировки: в первом терминале `terraform apply` (не отвечать
`yes`), во втором:

```bash
aws --endpoint-url=http://localhost:8333 s3 ls s3://terraform-state --recursive
terraform plan
```

```text
2026-10-14 20:57:16       7008 lab/terraform.tfstate
2026-10-14 20:57:23        213 lab/terraform.tfstate.tflock

Error: Error acquiring the state lock
... api error PreconditionFailed ...
Lock Info:
  ID:        0db7ee14-e5e0-c7ab-d19d-97db70c295c1
  Path:      terraform-state/lab/terraform.tfstate
  Operation: OperationTypeApply
  Who:       user@host
```

В первом терминале ответить `no` — lock-файл исчезнет. Уборка:

```bash
terraform destroy
docker rm -f tf-s3
```

Почему так: с `use_lockfile = true` блокировка — это объект
`terraform.tfstate.tflock`, который Terraform создаёт условной записью
(«записать, только если объекта нет»); второй процесс получает
`412 PreconditionFailed`. Отдельная таблица DynamoDB не нужна.
`use_path_style` и `skip_*` нужны только для не-AWS хранилища.

## Упражнение 05 — Workspaces

```bash
cd 5_iac/01_terraform_core/04_exercises_answers/ex05_workspaces/
terraform init

terraform workspace new dev
terraform plan -out=dev.tfplan
terraform apply dev.tfplan

terraform workspace new prod
terraform plan -out=prod.tfplan
terraform apply prod.tfplan

terraform workspace list
docker ps --filter name=lab- --format '{{.Names}} {{.Ports}}'
```

Ожидаемый вывод (примерно так):

```text
Created and switched to workspace "dev"!
Plan: 3 to add, 0 to change, 0 to destroy.
urls = [
  "http://localhost:8100",
]
Created and switched to workspace "prod"!
Plan: 5 to add, 0 to change, 0 to destroy.
urls = [
  "http://localhost:8200",
  "http://localhost:8201",
  "http://localhost:8202",
]
  default
  dev
* prod
lab-prod-nginx-0 0.0.0.0:8200->80/tcp
lab-prod-nginx-1 0.0.0.0:8201->80/tcp
lab-prod-nginx-2 0.0.0.0:8202->80/tcp
lab-dev-nginx-0 0.0.0.0:8100->80/tcp
```

Уборка — каждый workspace отдельно, затем удалить сами workspace:

```bash
terraform destroy                 # сейчас выбран prod
terraform workspace select dev
terraform destroy
terraform workspace select default
terraform workspace delete dev
terraform workspace delete prod
```

Почему так: у каждого workspace свой state, но Docker-хост один.
Если имена сети и контейнеров не содержат `terraform.workspace`, второй
`apply` упадёт с конфликтом имени (`lab-app-network` уже существует) и
занятого порта. В workspace `default` конфигурация намеренно падает на
`plan`/`validate` (`Invalid index`) — окружение нужно выбрать явно.
