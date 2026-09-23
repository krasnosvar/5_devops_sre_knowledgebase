#!/usr/bin/env bash
# Получить секреты из Vault через GitLab OIDC JWT (без статических credentials)
# Размещать как script в .gitlab-ci.yml job

# Переменные предоставляет GitLab автоматически:
# CI_JOB_JWT_V2 — OIDC JWT токен для текущего job
# VAULT_ADDR    — задать в GitLab CI/CD Variables

VAULT_ADDR="${VAULT_ADDR:?VAULT_ADDR required}"
VAULT_ROLE="${VAULT_ROLE:-gitlab-deploy}"

echo "Authenticating to Vault via JWT..."

# Получить Vault token через JWT auth
VAULT_TOKEN=$(curl -s \
    --request POST \
    --data "{\"jwt\": \"$CI_JOB_JWT_V2\", \"role\": \"$VAULT_ROLE\"}" \
    "$VAULT_ADDR/v1/auth/jwt/login" \
    | jq -r '.auth.client_token')

if [[ -z "$VAULT_TOKEN" || "$VAULT_TOKEN" == "null" ]]; then
    echo "ERROR: Failed to get Vault token" >&2
    exit 1
fi

export VAULT_TOKEN

echo "Fetching secrets..."

# Прочитать секреты
DB_PASSWORD=$(vault kv get -field=password secret/production/database)
API_KEY=$(vault kv get -field=api_key secret/production/external-api)

# Экспортировать для использования в последующих шагах
echo "DB_PASSWORD=${DB_PASSWORD}" >> deploy.env
echo "API_KEY=${API_KEY}" >> deploy.env

# Маскировать в логах GitLab (добавить в masked variables)
echo "Secrets fetched successfully"

# Vault token автоматически истечёт после lease_duration (1h по умолчанию)
