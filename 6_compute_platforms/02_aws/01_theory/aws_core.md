# AWS Core — ключевые сервисы

## Глобальная инфраструктура

**Region** — географическое расположение дата-центров (eu-central-1, us-east-1).
**Availability Zone (AZ)** — изолированный дата-центр внутри Region. Минимум 3 AZ на Region.
**Edge Location** — точки присутствия CloudFront CDN (400+).

Высокодоступная архитектура: ресурсы в 2-3 AZ, LB распределяет трафик.

## IAM — Identity and Access Management

```bash
# Структура: User/Group/Role → Policy → Permissions

# Проверить текущую идентичность
aws sts get-caller-identity

# Создать роль (для EC2 инстанса)
aws iam create-role \
  --role-name MyEC2Role \
  --assume-role-policy-document file://ec2-trust-policy.json

# ec2-trust-policy.json (Trust Policy — кто может принять роль)
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "ec2.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}

# Прикрепить политику к роли
aws iam attach-role-policy \
  --role-name MyEC2Role \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

# IRSA — роль для k8s ServiceAccount в EKS
# Trust Policy содержит OIDC issuer кластера вместо ec2.amazonaws.com
```

## VPC — Virtual Private Cloud

```
VPC (10.0.0.0/16)
├── Public Subnet (10.0.1.0/24) — AZ a
│   └── Internet Gateway → NAT Gateway → Internet
├── Public Subnet (10.0.2.0/24) — AZ b
├── Private Subnet (10.0.11.0/24) — AZ a (EC2, RDS)
│   └── NAT Gateway → Internet (только исходящий трафик)
└── Private Subnet (10.0.12.0/24) — AZ b
```

```bash
# создать VPC через CLI
aws ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications \
  'ResourceType=vpc,Tags=[{Key=Name,Value=prod-vpc}]'

# посмотреть все VPC
aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=production"

# Security Groups — stateful firewall для EC2
aws ec2 create-security-group \
  --group-name web-sg \
  --description "Web server security group" \
  --vpc-id vpc-12345

aws ec2 authorize-security-group-ingress \
  --group-id sg-12345 \
  --protocol tcp --port 443 --cidr 0.0.0.0/0
```

## EC2 — виртуальные машины

```bash
# запустить инстанс
aws ec2 run-instances \
  --image-id ami-0c7af5f9b3b0de3e4 \    # Ubuntu 24.04 eu-central-1
  --instance-type t3.micro \
  --key-name my-key \
  --security-group-ids sg-12345 \
  --subnet-id subnet-12345 \
  --iam-instance-profile Name=MyEC2Role \
  --user-data file://userdata.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=web-1}]'

# instance types по назначению:
# t3/t4g — general purpose, burstable (dev, small web)
# m5/m6i — general purpose, balanced (production web, app servers)
# c5/c6i — compute optimized (CPU-heavy)
# r5/r6i — memory optimized (DB, cache)
# p3/p4/p5 — GPU (ML training)
# i3/i4i — storage optimized (DB, Elasticsearch)

# Spot instances — до 90% дешевле, могут быть прерваны с 2 мин предупреждением
aws ec2 run-instances \
  --instance-market-options '{"MarketType":"spot","SpotOptions":{"SpotInstanceType":"one-time"}}'
```

## S3 — объектное хранилище

```bash
# создать bucket
aws s3 mb s3://my-bucket --region eu-central-1

# загрузить файлы
aws s3 cp file.txt s3://my-bucket/
aws s3 sync ./local-dir/ s3://my-bucket/prefix/ --delete

# скачать
aws s3 cp s3://my-bucket/file.txt ./
aws s3 sync s3://my-bucket/prefix/ ./local-dir/

# статический сайт
aws s3 website s3://my-bucket \
  --index-document index.html \
  --error-document error.html

# presigned URL (временный публичный доступ к приватному файлу)
aws s3 presign s3://my-bucket/secret-file.pdf --expires-in 3600

# lifecycle: переместить в IA через 30 дней, удалить через 365
aws s3api put-bucket-lifecycle-configuration \
  --bucket my-bucket \
  --lifecycle-configuration file://lifecycle.json
```

## EKS — Managed Kubernetes

```bash
# создать кластер
eksctl create cluster \
  --name my-cluster \
  --region eu-central-1 \
  --nodegroup-name workers \
  --node-type m5.large \
  --nodes 3 \
  --nodes-min 2 \
  --nodes-max 10 \
  --managed

# настроить kubectl
aws eks update-kubeconfig --name my-cluster --region eu-central-1

# добавить node group (Spot для non-critical workloads)
eksctl create nodegroup \
  --cluster my-cluster \
  --name spot-workers \
  --node-type m5.large,m5a.large,m4.large \
  --spot \
  --nodes 0 --nodes-min 0 --nodes-max 20

# IRSA — IAM роль для k8s ServiceAccount
eksctl create iamserviceaccount \
  --cluster my-cluster \
  --namespace production \
  --name myapp \
  --attach-policy-arn arn:aws:iam::123456789:policy/myapp-policy \
  --approve
```

## RDS — Managed Database

```bash
# создать PostgreSQL
aws rds create-db-instance \
  --db-instance-identifier prod-postgres \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 16.2 \
  --master-username admin \
  --master-user-password supersecret \
  --allocated-storage 20 \
  --storage-type gp3 \
  --storage-encrypted \
  --multi-az \                     # standby в другой AZ
  --vpc-security-group-ids sg-db \
  --db-subnet-group-name my-db-subnet-group

# snapshot и restore
aws rds create-db-snapshot \
  --db-instance-identifier prod-postgres \
  --db-snapshot-identifier prod-postgres-20240115

aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier restored-postgres \
  --db-snapshot-identifier prod-postgres-20240115
```

## ECR — Container Registry

```bash
# создать репозиторий
aws ecr create-repository --repository-name myapp

# логин (действует 12 часов)
aws ecr get-login-password --region eu-central-1 | \
  docker login --username AWS --password-stdin \
  123456789.dkr.ecr.eu-central-1.amazonaws.com

# push образа
docker tag myapp:latest 123456789.dkr.ecr.eu-central-1.amazonaws.com/myapp:latest
docker push 123456789.dkr.ecr.eu-central-1.amazonaws.com/myapp:latest

# lifecycle policy (удалять старые образы)
aws ecr put-lifecycle-policy \
  --repository-name myapp \
  --lifecycle-policy-text file://ecr-lifecycle.json
```

## Cost Optimization

```bash
# Посмотреть расходы
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# Типичные способы снижения затрат:
# 1. Reserved Instances / Savings Plans (1-3 года, скидка 40-70%)
# 2. Spot Instances (для stateless, batch, dev/test)
# 3. Rightsizing (уменьшить oversized инстансы)
# 4. S3 lifecycle policies (IA, Glacier для старых данных)
# 5. Удалить неиспользуемые ресурсы (EBS, EIP, NAT GW)

# Найти неиспользуемые EBS тома
aws ec2 describe-volumes \
  --filters Name=status,Values=available \
  --query 'Volumes[*].{ID:VolumeId,Size:Size,AZ:AvailabilityZone}'
```
