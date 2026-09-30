#!/usr/bin/env bash
# AWS CLI быстрый справочник — частые команды

# ── EC2 ───────────────────────────────────────────────────────────────────────
# Список инстансов
aws ec2 describe-instances \
    --query 'Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,PublicIpAddress,Tags[?Key==`Name`]|[0].Value]' \
    --output table

# Запустить инстанс
aws ec2 run-instances \
    --image-id ami-0c7af5f9b3b0de3e4 \
    --instance-type t3.micro \
    --key-name my-key \
    --security-group-ids sg-xxx \
    --subnet-id subnet-xxx \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=test}]'

# Остановить/запустить/удалить
aws ec2 stop-instances --instance-ids i-xxx
aws ec2 start-instances --instance-ids i-xxx
aws ec2 terminate-instances --instance-ids i-xxx

# ── S3 ────────────────────────────────────────────────────────────────────────
aws s3 ls                               # список bucket'ов
aws s3 ls s3://my-bucket/prefix/        # содержимое
aws s3 cp file.txt s3://my-bucket/      # загрузить
aws s3 sync ./local/ s3://my-bucket/remote/ --delete  # синхронизировать
aws s3 presign s3://my-bucket/file.pdf --expires-in 3600  # presigned URL

# ── IAM ───────────────────────────────────────────────────────────────────────
aws iam get-user                        # текущий пользователь
aws iam list-attached-user-policies --user-name my-user
aws iam simulate-principal-policy \     # проверить права
    --policy-source-arn arn:aws:iam::123456789:user/my-user \
    --action-names s3:GetObject s3:PutObject \
    --resource-arns arn:aws:s3:::my-bucket/*

# ── EKS ───────────────────────────────────────────────────────────────────────
aws eks list-clusters
aws eks update-kubeconfig --name my-cluster --region eu-central-1
aws eks describe-cluster --name my-cluster --query 'cluster.{version:.version,status:.status}'

# ── Costs ─────────────────────────────────────────────────────────────────────
aws ce get-cost-and-usage \
    --time-period Start=2024-01-01,End=2024-02-01 \
    --granularity MONTHLY \
    --metrics BlendedCost \
    --group-by Type=DIMENSION,Key=SERVICE \
    --query 'ResultsByTime[0].Groups[?Metrics.BlendedCost.Amount>`10`].[Keys[0],Metrics.BlendedCost.Amount]' \
    --output table

# Найти неиспользуемые EBS тома
aws ec2 describe-volumes \
    --filters Name=status,Values=available \
    --query 'Volumes[*].[VolumeId,Size,AvailabilityZone,CreateTime]' \
    --output table
