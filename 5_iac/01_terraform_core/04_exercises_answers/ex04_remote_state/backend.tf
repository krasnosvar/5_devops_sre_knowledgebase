# Ответ к упражнению 04: remote state в локальном S3-совместимом
# хранилище (SeaweedFS в Docker) с блокировкой через lock-файл в S3.
#
# Рядом с этим файлом должен лежать main.tf из
# ../../02_examples/main.tf (скопировать перед terraform init).
#
# use_lockfile = true (Terraform 1.10+): lock — это объект
# <key>.tflock в том же бакете, создаётся условной записью
# (If-None-Match). DynamoDB для блокировок больше не нужна;
# dynamodb_table в S3 backend помечен как deprecated.
#
# Учётные данные S3 НЕ пишутся в backend-блок: они берутся из
# AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY (для SeaweedFS без
# настроенных пользователей подойдут любые, например test/test).

terraform {
  backend "s3" {
    bucket       = "terraform-state"
    key          = "lab/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true

    endpoints = {
      s3 = "http://localhost:8333"
    }

    # Нужно для S3-совместимых хранилищ (не AWS):
    use_path_style              = true # http://host/bucket/key
    skip_credentials_validation = true # не ходить в AWS STS
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true # не искать EC2 metadata
    skip_region_validation      = true
  }
}
