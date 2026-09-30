#!/usr/bin/env bash
# Ответы: упражнения по модулям Terraform

BASE="../../02_examples"
cd "$BASE"

echo "=== Упражнение 01: базовое использование модуля ==="
terraform init
terraform apply -auto-approve
terraform output urls
curl -sf http://localhost:8081 | head -c 100
terraform destroy -auto-approve

echo -e "\n=== Упражнение 02: for_each — 4 окружения из map ==="
# Уже реализовано в main.tf через local.environments
# Проверить что создались все 4 контейнера:
terraform apply -auto-approve
docker ps --filter name=nginx- --format "table {{.Names}}\t{{.Ports}}"
terraform destroy -auto-approve

echo -e "\n=== Упражнение 03: validation в variables ==="
# Проверить что validation отклоняет неверные значения:
echo "Тест: невалидный port (должна быть ошибка):"
terraform plan -var="port=80" 2>&1 | grep "Error\|validation" | head -3 || \
    echo "Validation сработала"

echo "Тест: невалидный name (должна быть ошибка):"
terraform plan -var="name=My App!" 2>&1 | grep "Error\|validation" | head -3 || \
    echo "Validation сработала"

echo "Тест: валидные значения:"
terraform plan -var="port=8085" -var="name=valid-name" 2>&1 | grep "Plan:" | head -1
