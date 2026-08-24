# Упражнения — Secrets Management

Стенд: 🐳 Tier 1 — Vault из `9_security/02_secrets_management/02_examples/`

```bash
cd ../02_examples/
docker compose up -d
# Vault UI: http://localhost:8200 (token: dev-root-token)
```

## 01 — Базовая работа с Vault KV

```bash
export VAULT_ADDR="http://localhost:8200"
export VAULT_TOKEN="dev-root-token"

# Записать секрет
vault kv put secret/myapp/database \
  username=appuser \
  password=s3cr3t123 \
  host=postgres:5432

# Прочитать
vault kv get secret/myapp/database
vault kv get -field=password secret/myapp/database

# Версионирование (KV v2 хранит историю)
vault kv put secret/myapp/database password=newpassword123
vault kv get secret/myapp/database              # version 2
vault kv get -version=1 secret/myapp/database   # version 1
vault kv metadata get secret/myapp/database     # история версий
```

## 02 — Динамические секреты для PostgreSQL

```bash
# Поднять PostgreSQL рядом с Vault
docker run -d --name postgres \
  --network=02_examples_default \
  -e POSTGRES_PASSWORD=vaultpassword \
  -e POSTGRES_DB=appdb \
  postgres:16-alpine

# Включить database secret engine
vault secrets enable database

# Настроить подключение
vault write database/config/myapp \
  plugin_name=postgresql-database-plugin \
  allowed_roles="app-role" \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/appdb?sslmode=disable" \
  username="postgres" \
  password="vaultpassword"

# Создать role — шаблон для динамических credentials
vault write database/roles/app-role \
  db_name=myapp \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"

# Получить динамические credentials (каждый раз новые!)
vault read database/creds/app-role
# username: v-app-role-AbCd1234
# password: <random>
# lease_duration: 1h
```

## 03 — Policy — принцип наименьших привилегий

```bash
# Создать policy только для чтения секретов приложения
cat > /tmp/app-policy.hcl << 'ENDPOLICY'
path "secret/data/myapp/*" {
  capabilities = ["read", "list"]
}
path "database/creds/app-role" {
  capabilities = ["read"]
}
ENDPOLICY

vault policy write app-policy /tmp/app-policy.hcl

# Создать token с этой policy
APP_TOKEN=$(vault token create -policy=app-policy -format=json | jq -r '.auth.client_token')

# Проверить ограничения
VAULT_TOKEN=$APP_TOKEN vault kv get secret/myapp/database      # OK
VAULT_TOKEN=$APP_TOKEN vault kv list secret/                    # FORBIDDEN
```

## 04 — gitleaks — найти утечки секретов

```bash
# Установить gitleaks: https://github.com/gitleaks/gitleaks

# Создать тестовый репозиторий с "утечкой"
mkdir /tmp/test-repo && cd /tmp/test-repo && git init

# Записать "секрет" в файл
printf 'AWS_ACCESS_KEY_ID = "AKIAIOSFODNN7EXAMPLE"\n' > config.py
printf 'DB_PASSWORD = "supersecret123"\n' >> config.py
git add . && git commit -m "Add config"

# Сканировать
gitleaks detect --source . --verbose

# Вопрос: как правильно исправить?
# 1. Удалить из кода
# 2. Использовать переменные окружения
# 3. Добавить .env в .gitignore
# 4. Ротировать скомпрометированные ключи
# 5. git filter-branch / BFG для очистки истории
```
