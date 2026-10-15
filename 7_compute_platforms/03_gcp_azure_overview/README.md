# 03. GCP и Azure — обзор

## Зачем
На практике редко работают только с одним облаком: компания может жить в
GCP ради BigQuery или в Azure из-за Microsoft-стека. Тема переводит
знание AWS на язык двух других крупных облаков — терминология, модель
IAM, managed Kubernetes (GKE, AKS) — и помогает понять, когда выбор
другого облака оправдан.

## Пререквизиты
- [02_aws](../02_aws/) — тема построена как сравнение с AWS.
- [4_kubernetes](../../4_kubernetes/) — для разделов о GKE и AKS.
- [6_cicd](../../6_cicd/) — для сравнения Azure DevOps и GitHub Actions.

## Файлы
- [01_theory/gcp_azure.md](./01_theory/gcp_azure.md) — таблица соответствия
  сервисов AWS/GCP/Azure; GCP: service accounts, Workload Identity, GKE
  Autopilot vs Standard, BigQuery и Vertex AI, Cloud Armor; Azure:
  Managed Identity, AKS, Azure DevOps; критерии выбора облака.

Без примеров и упражнений: для лабы нужны реальные аккаунты GCP/Azure
(☁️ Tier 3).

## Как проходить
1. Прочитать таблицу терминологии и для каждой строки вспомнить аналог в
   AWS.
2. Прочитать разделы GCP и Azure, обращая внимание на отличия модели IAM
   от AWS.
3. По желанию: в бесплатном пробном периоде провайдера создать кластер
   GKE Autopilot или AKS и удалить его после проверки.

## Когда двигаться дальше
- Можете сопоставить VPC, IAM Role, EKS, S3 с аналогами в GCP и Azure.
- Можете объяснить, чем Workload Identity в GKE похож на IRSA в EKS.
- Можете назвать 2-3 аргумента в пользу GCP или Azure вместо AWS.

Дальше — [04_multi_cloud_and_hybrid](../04_multi_cloud_and_hybrid/).
