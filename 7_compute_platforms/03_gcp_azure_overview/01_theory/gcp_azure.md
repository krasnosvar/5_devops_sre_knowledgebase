# GCP и Azure — обзор для DevOps

## Сравнение терминологии AWS/GCP/Azure

| Концепция | AWS | GCP | Azure |
|-----------|-----|-----|-------|
| Виртуальная сеть | VPC | VPC | Virtual Network (VNet) |
| Виртуальная машина | EC2 | Compute Engine | Virtual Machine |
| Объектное хранилище | S3 | Cloud Storage | Blob Storage |
| Managed k8s | EKS | GKE | AKS |
| Container Registry | ECR | Artifact Registry | Azure Container Registry |
| Managed PostgreSQL | RDS | Cloud SQL | Azure Database for PostgreSQL |
| Serverless functions | Lambda | Cloud Functions | Azure Functions |
| IAM роль для сервиса | IAM Role + Instance Profile | Service Account | Managed Identity |
| Межсетевой экран | Security Groups + NACL | VPC Firewall Rules | NSG (Network Security Group) |
| DNS | Route53 | Cloud DNS | Azure DNS |
| CDN | CloudFront | Cloud CDN | Azure CDN |

## GCP — особенности для DevOps

### IAM — Service Accounts вместо Roles

```bash
# Создать Service Account
gcloud iam service-accounts create my-sa \
  --description="My service account" \
  --display-name="My SA"

# Назначить роль
gcloud projects add-iam-policy-binding my-project \
  --member="serviceAccount:my-sa@my-project.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"

# Workload Identity Federation (аналог AWS IRSA для GKE)
gcloud iam service-accounts add-iam-policy-binding my-sa@my-project.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:my-project.svc.id.goog[default/my-k8s-sa]"
```

### GKE (Google Kubernetes Engine)

```bash
# Autopilot — полностью управляемый (Google управляет нодами)
gcloud container clusters create-auto my-cluster \
  --region europe-west3

# Standard — управляешь нодами сам
gcloud container clusters create my-cluster \
  --zone europe-west3-a \
  --num-nodes 3 \
  --machine-type n2-standard-4

# Получить kubeconfig
gcloud container clusters get-credentials my-cluster --zone europe-west3-a
```

### BigQuery и Vertex AI — уникальные сильные стороны GCP

```bash
# BigQuery — аналитический SQL на петабайтах без управления инфраструктурой
# Важно для MLOps: feature store, training data, метрики

# Vertex AI — managed ML platform
# Model Registry, Pipeline Orchestration, Endpoint для serving
# Когда выбирать GCP: если команда работает с большими данными и ML
```

### Cloud Armor — WAF и DDoS защита

```bash
gcloud compute security-policies create my-policy
gcloud compute security-policies rules create 1000 \
  --security-policy my-policy \
  --expression "origin.region_code == 'CN'" \
  --action "deny-403"
```

## Azure — особенности для DevOps

### Azure Active Directory и Managed Identity

```bash
# Managed Identity — аналог AWS IAM Role для VM
# System-assigned: привязана к ресурсу, удаляется вместе с ним
# User-assigned: независимая, можно назначить нескольким ресурсам

az identity create --name my-identity --resource-group mygroup

# Назначить Managed Identity Azure VM
az vm identity assign --name my-vm \
  --resource-group mygroup \
  --identities my-identity

# Workload Identity для AKS
az aks update --name my-cluster \
  --resource-group mygroup \
  --enable-oidc-issuer \
  --enable-workload-identity
```

### AKS (Azure Kubernetes Service)

```bash
# Создать кластер
az aks create \
  --resource-group mygroup \
  --name my-cluster \
  --node-count 3 \
  --node-vm-size Standard_D4s_v3 \
  --enable-managed-identity \
  --enable-addons monitoring \
  --generate-ssh-keys

# Получить kubeconfig
az aks get-credentials --resource-group mygroup --name my-cluster

# Обновить кластер
az aks upgrade --resource-group mygroup --name my-cluster --kubernetes-version 1.29
```

### Azure DevOps vs GitHub Actions

Azure DevOps — собственная платформа Microsoft (CI/CD, boards, repos, artifacts).
GitHub Actions — часть GitHub, более популярна в open-source.

```yaml
# azure-pipelines.yml — аналог .gitlab-ci.yml
trigger:
  branches:
    include: [main]

pool:
  vmImage: ubuntu-latest

steps:
  - task: Docker@2
    displayName: Build image
    inputs:
      command: buildAndPush
      repository: myacr.azurecr.io/myapp
      tags: $(Build.BuildId)
```

## Когда выбирать GCP vs Azure vs AWS

**GCP:**
- Команда активно использует BigQuery, Vertex AI, Pub/Sub
- Нужен Autopilot GKE (минимальное операционное бремя)
- Стартапы в AI/ML пространстве

**Azure:**
- Компания использует Microsoft 365, Active Directory
- .NET / Windows приложения
- Enterprise с Microsoft EA (Enterprise Agreement) — большие скидки

**AWS:**
- Default выбор для большинства случаев
- Крупнейшая экосистема сервисов и провайдеров
- Лучшая документация и сообщество
