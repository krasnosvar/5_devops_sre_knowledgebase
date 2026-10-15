#!/usr/bin/env bash
# Получить секреты из Vault через GitLab OIDC JWT (без статических credentials).
#
# JWT джоба получает через `id_tokens:` (GitLab 15.7+). Старые переменные
# CI_JOB_JWT / CI_JOB_JWT_V2 удалены в GitLab 17.0 — не использовать.
#
# Пример джобы в .gitlab-ci.yml:
#
#   deploy:
#     image: hashicorp/vault:1.17
#     id_tokens:
#       VAULT_ID_TOKEN:
#         aud: https://vault.example.com   # = bound_audiences роли в Vault
#     variables:
#       VAULT_ADDR: https://vault.example.com
#       VAULT_ROLE: gitlab-deploy
#     before_script:
#       - apk add --no-cache curl jq
#     script:
#       - source ./vault-oidc-gitlab.sh   # source: переменные нужны дальше
#       - ./deploy.sh                     # читает DB_PASSWORD / API_KEY из env
#
# Скрипт рассчитан на `source`: секреты экспортируются в окружение текущей
# джобы и НЕ пишутся на диск (файл легко случайно отдать как artifact).

set -euo pipefail

: "${VAULT_ADDR:?VAULT_ADDR не задан (CI/CD Variables)}"
: "${VAULT_ROLE:?VAULT_ROLE не задан (имя роли в auth/jwt Vault)}"
: "${VAULT_ID_TOKEN:?VAULT_ID_TOKEN пуст: в джобе нет блока id_tokens}"

echo "Authenticating to Vault via JWT (role: ${VAULT_ROLE})..."

# --fail: HTTP 4xx/5xx -> ненулевой код, set -e остановит джобу
VAULT_TOKEN=$(curl --silent --show-error --fail \
    --request POST \
    --data "{\"jwt\": \"${VAULT_ID_TOKEN}\", \"role\": \"${VAULT_ROLE}\"}" \
    "${VAULT_ADDR}/v1/auth/jwt/login" \
    | jq -r '.auth.client_token')

if [[ -z "$VAULT_TOKEN" || "$VAULT_TOKEN" == "null" ]]; then
    echo "ERROR: Vault не вернул client_token" >&2
    exit 1
fi
export VAULT_TOKEN

echo "Fetching secrets..."

# Прочитать секреты (KV v2) — только в память процесса джобы
DB_PASSWORD=$(vault kv get -field=password secret/production/database)
API_KEY=$(vault kv get -field=api_key secret/production/external-api)
export DB_PASSWORD API_KEY

# Значения не печатаем: маскирование в логах защищает только от точного
# совпадения строки (см. теорию, раздел 5)
echo "Secrets fetched"

# Vault token истечёт сам по TTL роли (token_ttl); короткий TTL (5-15 мин)
# ограничивает ущерб, если токен всё же утечёт.
