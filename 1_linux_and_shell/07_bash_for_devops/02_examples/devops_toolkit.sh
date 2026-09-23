#!/usr/bin/env bash
# Практические DevOps-паттерны — готовые функции для копипасты
set -euo pipefail

# ── retry с экспоненциальным backoff ─────────────────────────────────────────
retry() {
    local max=$1 delay=${2:-2}; shift 2
    local attempt=1
    until "$@"; do
        (( attempt >= max )) && { echo "FAILED after $max attempts: $*" >&2; return 1; }
        echo "Attempt $attempt/$max failed, retrying in ${delay}s..." >&2
        sleep "$delay"; (( attempt++ )); (( delay = delay * 2 ))
    done
}

# ── wait_for_url — ждать пока сервис станет доступен ─────────────────────────
wait_for_url() {
    local url=$1 max=${2:-30} interval=${3:-2}
    echo "Waiting for $url..."
    retry "$max" "$interval" curl -sf --max-time 3 "$url" > /dev/null
    echo "$url is up!"
}

# ── lockfile — предотвратить параллельный запуск ─────────────────────────────
LOCK=/tmp/$(basename "$0").lock
exec 9>"$LOCK"
flock -n 9 || { echo "Already running. Exiting." >&2; exit 1; }
trap 'rm -f "$LOCK"' EXIT

# ── log — структурированное логирование ──────────────────────────────────────
log() {
    local level=$1; shift
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [$level] $*" >&2
}

# ── check_required — проверить обязательные переменные ───────────────────────
check_required() {
    local missing=0
    for var in "$@"; do
        [[ -z "${!var:-}" ]] && { echo "ERROR: $var is required" >&2; missing=1; }
    done
    (( missing )) && exit 1
}

# ── json_field — извлечь поле из JSON (без jq) ───────────────────────────────
json_field() {
    python3 -c "import sys,json; print(json.load(sys.stdin)$1)"
}

# ── Демонстрация ──────────────────────────────────────────────────────────────
log INFO "Script started"

# Проверить переменные
export DEPLOY_ENV=${DEPLOY_ENV:-staging}
export IMAGE_TAG=${IMAGE_TAG:-latest}
check_required DEPLOY_ENV IMAGE_TAG

log INFO "Deploying $IMAGE_TAG to $DEPLOY_ENV"

# Retry пример
retry 3 1 true   # успех сразу
log INFO "Retry demo passed"

# JSON parsing
echo '{"version":"1.2.3","status":"ok"}' | json_field '["version"]'

log INFO "Script completed successfully"
