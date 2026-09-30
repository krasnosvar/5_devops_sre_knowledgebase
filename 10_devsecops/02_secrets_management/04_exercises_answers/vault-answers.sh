#!/usr/bin/env bash
# Ответы: Vault упражнения
# Предварительно: docker compose up -d (из ../02_examples/)

export VAULT_ADDR="http://localhost:8200"
export VAULT_TOKEN="dev-root-token"

echo "=== Упражнение 01: KV secrets ==="
vault kv put secret/myapp/database \
    username=appuser \
    password=s3cr3t123 \
    host=postgres:5432

vault kv get secret/myapp/database
echo "Password only: $(vault kv get -field=password secret/myapp/database)"

# Версионирование
vault kv put secret/myapp/database password=newpassword456
vault kv get secret/myapp/database              # version 2
vault kv get -version=1 secret/myapp/database   # version 1

echo -e "\n=== Упражнение 03: Policy ==="
cat > /tmp/app-policy.hcl << 'EOF'
path "secret/data/myapp/*" {
  capabilities = ["read", "list"]
}
EOF

vault policy write app-policy /tmp/app-policy.hcl
echo "Policy created:"
vault policy read app-policy

# Создать token с этой policy
APP_TOKEN=$(vault token create -policy=app-policy -format=json | jq -r '.auth.client_token')
echo "App token: ${APP_TOKEN:0:20}..."

# Проверить ограничения
echo -e "\nReading with app-token (должно работать):"
VAULT_TOKEN=$APP_TOKEN vault kv get secret/myapp/database && echo "✓ OK"

echo "Writing with app-token (должно быть запрещено):"
VAULT_TOKEN=$APP_TOKEN vault kv put secret/admin/key val=test 2>&1 | grep "permission denied" \
    && echo "✓ Forbidden as expected"

echo -e "\n=== Упражнение 04: gitleaks ==="
# Симулировать найденные секреты
cat > /tmp/scan-results.json << 'EOF'
[
  {
    "Description": "AWS Access Key ID",
    "StartLine": 1,
    "Match": "AKIAIOSFODNN7EXAMPLE",
    "Secret": "AKIAIOSFODNN7EXAMPLE",
    "File": "config.py"
  }
]
EOF
echo "gitleaks found:"
cat /tmp/scan-results.json | jq '.[] | "File: \(.File) Line: \(.StartLine) Type: \(.Description)"' -r

echo -e "\nКак исправить:"
echo "1. Удалить из файла, использовать переменные окружения"
echo "2. Добавить .env в .gitignore"
echo "3. Ротировать скомпрометированный ключ в AWS IAM"
echo "4. Очистить git history: git filter-branch или BFG Repo Cleaner"

rm -f /tmp/app-policy.hcl /tmp/scan-results.json
