# GCP и Azure — шпаргалка

Подробности и объяснения — в [gcp_azure.md](./01_theory/gcp_azure.md).
⚠️ — опасная команда или частая ловушка.

## Соответствие сервисов

| Концепция | AWS | GCP | Azure |
| :--- | :--- | :--- | :--- |
| Иерархия | Organization → Account | Organization → Folder → Project | Tenant → Subscription → Resource Group |
| Сеть | VPC (регион) | VPC (**глобальная**, подсети региональные) | VNet (регион) |
| VM | EC2 | Compute Engine | Virtual Machines |
| Объекты | S3 | Cloud Storage | Blob Storage |
| Managed k8s | EKS | GKE (Standard / Autopilot) | AKS |
| Registry | ECR | Artifact Registry | Azure Container Registry |
| PostgreSQL | RDS / Aurora | Cloud SQL / AlloyDB | Azure Database for PostgreSQL |
| Функции | Lambda | Cloud Run functions | Azure Functions |
| Идентичность сервиса | IAM Role + instance profile | Service Account | Managed Identity |
| Права пода k8s | IRSA / Pod Identity | Workload Identity Federation for GKE | Microsoft Entra Workload ID |
| Firewall | SG + NACL | VPC Firewall Rules | NSG |
| DNS | Route 53 | Cloud DNS | Azure DNS |
| WAF / DDoS | AWS WAF / Shield | Cloud Armor | Azure WAF / DDoS Protection |
| Аудит API | CloudTrail | Cloud Audit Logs | Activity Log |

## gcloud: база

| Задача | Команда |
| :--- | :--- |
| Войти (человек) / для SDK и Terraform (ADC) | `gcloud auth login` / `gcloud auth application-default login` |
| Кто я, активный проект | `gcloud config list` |
| Выбрать проект / регион | `gcloud config set project my-project`<br>`gcloud config set compute/region europe-west3` |
| Профили конфигураций | `gcloud config configurations create dev` / `activate dev` |
| Формат и фильтр вывода | `--format='table(name,zone,status)'` / `--format=json` / `--filter='status=RUNNING'` |
| Список VM | `gcloud compute instances list` |
| SSH через IAP (без публичного IP) | `gcloud compute ssh vm-1 --zone europe-west3-a --tunnel-through-iap` |

## GCP: IAM и GKE

| Задача | Команда |
| :--- | :--- |
| Создать service account | `gcloud iam service-accounts create my-sa --display-name="My SA"` |
| Выдать роль на проект | `gcloud projects add-iam-policy-binding my-project --member="serviceAccount:my-sa@my-project.iam.gserviceaccount.com" --role="roles/storage.objectViewer"` |
| Связать KSA с GSA (Workload Identity) | `gcloud iam service-accounts add-iam-policy-binding my-sa@my-project.iam.gserviceaccount.com --role roles/iam.workloadIdentityUser --member "serviceAccount:my-project.svc.id.goog[default/my-k8s-sa]"` |
| Кластер Autopilot | `gcloud container clusters create-auto my-cluster --region europe-west3` |
| Кластер Standard | `gcloud container clusters create my-cluster --zone europe-west3-a --num-nodes 3 --machine-type n2-standard-4` |
| kubeconfig | `gcloud container clusters get-credentials my-cluster --zone europe-west3-a` |
| ⚠️ Удалить кластер | `gcloud container clusters delete my-cluster --zone europe-west3-a` |
| Cloud Armor: политика и правило | `gcloud compute security-policies create my-policy`<br>`gcloud compute security-policies rules create 1000 --security-policy my-policy --expression "origin.region_code == 'CN'" --action deny-403` |

- ⚠️ Для Workload Identity KSA также нужна аннотация
  `iam.gke.io/gcp-service-account=my-sa@my-project.iam.gserviceaccount.com`.
- ⚠️ `get-credentials` требует плагин `gke-gcloud-auth-plugin`.

## az: база

| Задача | Команда |
| :--- | :--- |
| Войти / через device code | `az login` / `az login --use-device-code` |
| Текущая подписка / выбрать | `az account show` / `az account set --subscription <id>` |
| Формат и фильтр (JMESPath) | `--output table\|json\|tsv` / `--query "[].{name:name,rg:resourceGroup}"` |
| Resource group | `az group create --name mygroup --location westeurope` |
| ⚠️ Удалить всё в группе | `az group delete --name mygroup --yes --no-wait` |
| Список VM | `az vm list -d --output table` |

## Azure: Managed Identity и AKS

| Задача | Команда |
| :--- | :--- |
| User-assigned identity | `az identity create --name my-identity --resource-group mygroup` |
| Назначить identity на VM | `az vm identity assign --name my-vm --resource-group mygroup --identities my-identity` |
| Создать AKS | `az aks create --resource-group mygroup --name my-cluster --node-count 3 --node-vm-size Standard_D4s_v3 --enable-managed-identity --generate-ssh-keys` |
| Включить Workload Identity | `az aks update --resource-group mygroup --name my-cluster --enable-oidc-issuer --enable-workload-identity` |
| kubeconfig | `az aks get-credentials --resource-group mygroup --name my-cluster` |
| Доступные версии / апгрейд | `az aks get-upgrades --resource-group mygroup --name my-cluster`<br>`az aks upgrade --resource-group mygroup --name my-cluster --kubernetes-version <ver>` |

| Тип Managed Identity | Жизненный цикл | Когда |
| :--- | :--- | :--- |
| System-assigned | живёт и удаляется вместе с ресурсом | один ресурс — одна identity |
| User-assigned | отдельный ресурс | одна identity на несколько VM/подов, переживает пересоздание |

## Когда что выбирать

| Ситуация | Облако |
| :--- | :--- |
| Дефолт, максимум сервисов и специалистов на рынке | AWS |
| Большие данные и ML (BigQuery, Vertex AI), минимум ops в k8s (Autopilot) | GCP |
| Microsoft 365 / Entra ID, .NET и Windows, Enterprise Agreement | Azure |
| CI в Azure DevOps (`azure-pipelines.yml`) или уже GitHub | Azure |

> Проверка: команды и флаги `gcloud` и `az` сверены с `--help` в образах
> `gcr.io/google.com/cloudsdktool/google-cloud-cli:slim` и
> `mcr.microsoft.com/azure-cli` (без логина и обращений к API);
> не проверено: актуальность названий продуктов и цен.
