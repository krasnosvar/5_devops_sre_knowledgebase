# S3 + DynamoDB backend для production
# Создать инфраструктуру перед первым использованием:
#   aws s3api create-bucket --bucket my-tfstate-prod --region eu-central-1 \
#       --create-bucket-configuration LocationConstraint=eu-central-1
#   aws s3api put-bucket-versioning --bucket my-tfstate-prod \
#       --versioning-configuration Status=Enabled
#   aws dynamodb create-table --table-name terraform-state-locks \
#       --attribute-definitions AttributeName=LockID,AttributeType=S \
#       --key-schema AttributeName=LockID,KeyType=HASH \
#       --billing-mode PAY_PER_REQUEST

terraform {
  backend "s3" {
    bucket         = "my-tfstate-prod"
    key            = "services/myapp/terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
    dynamodb_table = "terraform-state-locks"
  }
}

# Partial config (секреты не в коде):
# terraform init -backend-config=backend-secrets.hcl
#
# backend-secrets.hcl (не коммитить!):
# access_key = "AKIAIOSFODNN7EXAMPLE"
# secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
