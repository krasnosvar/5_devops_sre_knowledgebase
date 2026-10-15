# 02. AWS

## Зачем
AWS — самое распространённое публичное облако, и большая часть реальных
проектов так или иначе использует IAM, VPC, EC2, S3, RDS и EKS. Тема
даёт карту ключевых сервисов и то, как они устроены внутри: как
вычисляются права IAM, куда уходит трафик из приватной подсети, чем EBS
отличается от instance store и почему control plane EKS стоит денег.

## Пререквизиты
- [01_cloud_fundamentals](../01_cloud_fundamentals/) — регионы, AZ, модели
  оплаты, shared responsibility.
- [2_networking/06_vpc_and_cloud_networking](../../2_networking/06_vpc_and_cloud_networking/)
  — подсети, маршрутизация, NAT.
- [3_containers](../../3_containers/) — образы и registry (для ECR).
- [4_kubernetes](../../4_kubernetes/) — для разделов про EKS, IRSA и
  `kubectl`.
- [5_iac/01_terraform_core](../../5_iac/01_terraform_core/) — желательно:
  в реальной работе ресурсы AWS создают через Terraform, а не через CLI.

## Файлы
Теория — читать по номерам, начиная с обзора:
- [01_theory/00_aws_core.md](./01_theory/00_aws_core.md) — **обзор, читать
  первым**: глобальная инфраструктура, IAM, VPC, EC2, S3, EKS, RDS, ECR,
  cost optimization на примерах команд AWS CLI.
- [01_theory/01_aws_iam_and_security.md](./01_theory/01_aws_iam_and_security.md)
  — Users/Groups/Roles, identity- и resource-based политики, логика
  вычисления прав, KMS и envelope encryption, OIDC-федерация.
- [01_theory/02_aws_networking_vpc.md](./01_theory/02_aws_networking_vpc.md)
  — подсети и route tables, IGW vs NAT Gateway, SG vs NACL, peering и
  Transit Gateway, VPC Endpoints.
- [01_theory/03_aws_compute_ec2.md](./01_theory/03_aws_compute_ec2.md) —
  типы инстансов и цены, EBS vs instance store, ASG и Launch Templates,
  ALB/NLB/GWLB, user data и IMDSv2.
- [01_theory/04_aws_storage_s3.md](./01_theory/04_aws_storage_s3.md) —
  консистентность S3, классы хранения и lifecycle, безопасность бакетов,
  EFS vs EBS.
- [01_theory/05_aws_databases_rds.md](./01_theory/05_aws_databases_rds.md)
  — RDS Multi-AZ vs Read Replicas, Aurora, DynamoDB, ElastiCache,
  безопасность БД.
- [01_theory/06_aws_serverless_and_managed.md](./01_theory/06_aws_serverless_and_managed.md)
  — EKS и Fargate, Lambda и cold start, SQS/SNS, Route53, API Gateway.
- [02_examples/aws_quick_ref.md](./02_examples/aws_quick_ref.md) —
  справочник частых команд AWS CLI с пометками об опасных командах и
  `--dry-run`. Это не скрипт: команды копируются по одной.

Без упражнений с ответами: лаба требует реальный аккаунт AWS (☁️ Tier 3)
и стоит денег. Ориентир для самостоятельной практики — команды из
`00_aws_core.md` и `aws_quick_ref.md`, всегда с удалением ресурсов в
конце.

## Как проходить
1. Прочитать `00_aws_core.md` — получить общую карту сервисов.
2. Прочитать файлы `01`–`06` по порядку; в каждом сначала ответить на
   вопросы для собеседования самостоятельно, потом сверить с ответом.
3. Если есть аккаунт AWS: проверить условия Free Tier
   (https://aws.amazon.com/free/), настроить бюджет-алерт в Billing и
   только потом пройти команды из `aws_quick_ref.md`, сначала с
   `--dry-run`.
4. После практики удалить всё созданное (инстансы, NAT Gateway, кластеры
   EKS, EBS-тома) и проверить Cost Explorer через день.

## Когда двигаться дальше
- Можете объяснить, как AWS вычисляет итоговое решение Allow/Deny, когда
  на запрос действуют и identity-, и resource-based политики.
- Можете нарисовать VPC с публичными и приватными подсетями в двух AZ и
  объяснить путь пакета из приватной подсети в интернет.
- Можете назвать, какие ресурсы из лабы продолжают тарифицироваться, если
  их забыть (EKS control plane, NAT Gateway, EBS, Elastic IP).
- Понимаете, когда выбрать Multi-AZ RDS, а когда Read Replica.

Дальше — [03_gcp_azure_overview](../03_gcp_azure_overview/): как те же идеи
выглядят в GCP и Azure.
