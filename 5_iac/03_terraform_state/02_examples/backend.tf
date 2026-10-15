# S3 backend для production с блокировкой через lock-файл в S3
# (use_lockfile, Terraform 1.10+). Блокировка через DynamoDB
# (dynamodb_table) в S3 backend помечена как deprecated — для новых
# проектов таблица не нужна.
#
# Создать бакет перед первым использованием (это реальный AWS:
# нужны учётные данные, см. 7_compute_platforms/02_aws):
#   aws s3api create-bucket --bucket my-tfstate-prod --region eu-central-1 \
#       --create-bucket-configuration LocationConstraint=eu-central-1
#   aws s3api put-bucket-versioning --bucket my-tfstate-prod \
#       --versioning-configuration Status=Enabled
#
# Локальная тренировка без AWS-аккаунта:
#   5_iac/01_terraform_core/04_exercises_answers/ex04_remote_state/

terraform {
  backend "s3" {
    bucket       = "my-tfstate-prod"
    key          = "services/myapp/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}

# Учётные данные в backend-блок не пишутся: стандартная цепочка AWS SDK
# (AWS_PROFILE, переменные окружения, SSO, роль CI-раннера).
#
# Partial config (разные бакеты для окружений без правки кода):
#   terraform init -backend-config=backend-prod.hcl
#
# backend-prod.hcl:
#   bucket = "my-tfstate-prod"
#   key    = "services/myapp/terraform.tfstate"
