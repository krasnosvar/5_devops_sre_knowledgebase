# Облако и VPS для лаб — шпаргалка

Подробности и объяснения — в
[cloud_vps_options.md](./01_theory/cloud_vps_options.md).
⚠️ — опасная команда или частая ловушка. Цены и лимиты меняются —
сверяйтесь с прайсом провайдера.

## Когда нужен Tier 3

| Нужно | Локально хватит? |
| :--- | :--- |
| IAM, managed k8s, S3 и другие облачные сервисы | нет — облако |
| Внешний IP / публичный DNS | нет — облако или VPS |
| Многонодовый кластер на 16+ GB RAM | дорого локально — VPS |
| GPU для MLOps | нет — GPU по часам |
| Всё остальное | да — Tier 1 / Tier 2 |

## AWS CLI

| Задача | Команда |
| :--- | :--- |
| Настроить ключи IAM-пользователя | `aws configure` |
| Настроить SSO | `aws configure sso` |
| Кто я (проверка доступа) | `aws sts get-caller-identity` |
| Выбрать профиль на сессию | `export AWS_PROFILE=<name>` |
| Budget alert — до первого ресурса | `aws budgets create-budget --account-id <id> --budget file://budget.json --notifications-with-subscribers file://notifications.json` |
| Остановить EC2 (диск EBS тарифицируется) | `aws ec2 stop-instances --instance-ids <id>` |

## Hetzner Cloud (`hcloud`)

| Задача | Команда |
| :--- | :--- |
| Контекст с API-токеном | `hcloud context create my-project` |
| Загрузить SSH-ключ в проект | `hcloud ssh-key create --name lab-key --public-key-from-file ~/.ssh/lab_key.pub` |
| Создать сервер | `hcloud server create --name lab-node --type cx22 --image ubuntu-24.04 --location fsn1 --ssh-key lab-key` |
| Список / удалить ⚠️ | `hcloud server list` / `hcloud server delete lab-node` |
| ⚠️ | `--ssh-key` — имя или ID ключа в проекте, не путь к файлу |

## DigitalOcean (`doctl`)

| Задача | Команда |
| :--- | :--- |
| Авторизация токеном | `doctl auth init` |
| Создать droplet | `doctl compute droplet create lab-node --region fra1 --size s-2vcpu-4gb --image ubuntu-24-04-x64 --ssh-keys <key-id>` |
| ID ключей / размеры / образы | `doctl compute ssh-key list` / `doctl compute size list` / `doctl compute image list-distribution` |
| Список / удалить ⚠️ | `doctl compute droplet list` / `doctl compute droplet delete lab-node` |

## Terraform-стенд

| Задача | Команда |
| :--- | :--- |
| Скачать провайдер | `terraform init` |
| Посмотреть план | `terraform plan -var="hcloud_token=$HCLOUD_TOKEN"` |
| Создать | `terraform apply -var="hcloud_token=$HCLOUD_TOKEN"` |
| Удалить и перестать платить | `terraform destroy` |
| ⚠️ | токен не коммитить: `variable "hcloud_token" { sensitive = true }` + переменная окружения `TF_VAR_hcloud_token` |

## Ориентиры по стоимости

| Ресурс | Порядок цены |
| :--- | :--- |
| EKS control plane | $0.10/ч за кластер (~$73/мес) + ноды |
| Hetzner CX22 (2 vCPU / 4 GB) | ~€4/мес |
| RTX 4090 на RunPod | ~$0.74/ч → ~$18/сутки, если забыть |
| Остановленный EC2 | только EBS, ~$0.10/GB/мес |
| Spot / Preemptible | до −90%, могут отобрать (AWS: за 2 мин) |

## Правила экономии

| Правило | Как |
| :--- | :--- |
| Budget alert раньше первого ресурса | `aws budgets create-budget ...` |
| Стенд живёт один день | `terraform destroy` в конце упражнения |
| Пауза в разработке | остановить, а не удалить |
| Batch-задачи | Spot / Preemptible |
| GPU | удалить инстанс сразу после работы |
| Очистка тестового аккаунта ⚠️ | `aws-nuke` / `cloud-nuke` удаляют всё в регионе |

> Проверка: флаги `aws` сверены с `aws <cmd> help` (aws-cli 2.37),
> `hcloud` и `doctl` — с `--help` в образах `hetznercloud/cli`,
> `digitalocean/doctl`, HCL — `terraform validate` в scratch (без
> облачных вызовов); не проверено: актуальность типов (`cx22`) и цен.
