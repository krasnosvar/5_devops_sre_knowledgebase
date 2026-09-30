#!/usr/bin/env bash
# Ответы: упражнения Terraform с Docker provider

BASE="../../02_examples"

echo "=== Упражнение 01: первый apply ==="
cd "$BASE"
terraform init -input=false
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
terraform output nginx_url
curl -sf "$(terraform output -raw nginx_url)" | head -c 200
echo ""
terraform destroy -auto-approve

echo -e "\n=== Упражнение 02: variables + outputs ==="
terraform apply -auto-approve \
    -var="nginx_port=8090" \
    -var="app_name=my-lab"
echo "URL: $(terraform output -raw nginx_url)"
terraform destroy -auto-approve

echo -e "\n=== Упражнение 03: state + import ==="
terraform apply -auto-approve

# Удалить вручную
docker rm -f my-lab-nginx 2>/dev/null || true

# terraform план покажет drift
echo "Drift detection:"
terraform plan -refresh-only

# Import существующего контейнера
docker run -d --name manual-nginx -p 8091:80 nginx:alpine
terraform import docker_container.nginx manual-nginx
echo "Imported: $(terraform state show docker_container.nginx | grep name)"
terraform destroy -auto-approve

echo -e "\n=== Упражнение 05: workspaces ==="
terraform workspace new dev
terraform workspace new prod
terraform workspace select dev
terraform apply -auto-approve -var="nginx_port=8092"

terraform workspace select prod
terraform apply -auto-approve -var="nginx_port=8093"

echo "Dev:"   ; terraform workspace select dev  && terraform output nginx_url
echo "Prod:"  ; terraform workspace select prod && terraform output nginx_url

terraform workspace select dev  && terraform destroy -auto-approve
terraform workspace select prod && terraform destroy -auto-approve
terraform workspace select default
