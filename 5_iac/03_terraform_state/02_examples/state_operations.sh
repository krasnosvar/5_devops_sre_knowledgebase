#!/usr/bin/env bash
# Шпаргалка по операциям с Terraform state

# ── Просмотр ──────────────────────────────────────────────────────────────────
terraform state list                           # все ресурсы
terraform state list 'module.vpc.*'           # фильтр
terraform state show aws_instance.web          # атрибуты ресурса
terraform state pull > current.tfstate         # скачать state

# ── Перемещение (переименование без пересоздания) ─────────────────────────────
terraform state mv aws_instance.old aws_instance.new
terraform state mv 'module.old.aws_s3_bucket.data' 'module.new.aws_s3_bucket.data'

# ── Удаление из state (ресурс остаётся в AWS) ────────────────────────────────
terraform state rm aws_instance.temp
terraform state rm 'module.eks.aws_eks_cluster.this[0]'

# Bulk delete — убрать целый модуль из state
terraform state list | grep 'module.legacy' | xargs -I{} terraform state rm '{}'

# ── Import существующих ресурсов ──────────────────────────────────────────────
terraform import aws_s3_bucket.logs my-logs-bucket
terraform import aws_instance.web i-0abc123def456
terraform import 'aws_subnet.private[0]' subnet-0abc123

# ── Восстановление из S3 версионирования ─────────────────────────────────────
# aws s3api list-object-versions \
#     --bucket my-tfstate-prod \
#     --prefix services/myapp/terraform.tfstate \
#     --query 'Versions[*].[VersionId,LastModified]' \
#     --output table
#
# aws s3api get-object \
#     --bucket my-tfstate-prod \
#     --key services/myapp/terraform.tfstate \
#     --version-id VERSIONID \
#     backup.tfstate

# ── Снятие застрявшего lock ───────────────────────────────────────────────────
# terraform force-unlock LOCK_ID
# (LOCK_ID берётся из сообщения об ошибке)

# ── Drift detection ───────────────────────────────────────────────────────────
terraform plan -refresh-only        # показать drift без изменений
terraform apply -refresh-only       # обновить state под реальность
