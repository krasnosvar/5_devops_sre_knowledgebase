#!/usr/bin/env bash
# Ответ: упражнение 02 — retry с экспоненциальным backoff
set -euo pipefail

retry() {
    local max=$1 delay=${2:-1}; shift 2
    local attempt=1
    until "$@"; do
        (( attempt >= max )) && { echo "FAILED after $max attempts: $*" >&2; return 1; }
        echo "Attempt $attempt/$max failed, retrying in ${delay}s..." >&2
        sleep "$delay"
        (( attempt++ ))
        (( delay = delay * 2 < 60 ? delay * 2 : 60 ))  # cap at 60s
    done
    echo "Success on attempt $attempt" >&2
}

# Дождаться HTTP сервиса
wait_for_service() {
    local url=$1 max=${2:-30}
    retry "$max" 2 curl -sf --max-time 3 "$url" > /dev/null
    echo "Service $url is up!"
}

# Демонстрация: curl с retries
echo "=== Пример 1: retry команды ==="
retry 3 1 true  # успех сразу

echo -e "\n=== Пример 2: retry с неудачами ==="
attempt=0
retry 4 1 bash -c '
    (( ++attempt < 3 )) && { echo "Simulated failure $attempt" >&2; exit 1; }
    echo "Succeeded"
' || true

echo -e "\n=== Пример 3: ждать сервис ==="
# Ждать nginx если запущен, иначе продемонстрировать timeout
if curl -sf http://localhost:80 &>/dev/null; then
    wait_for_service "http://localhost:80/health" 5
else
    echo "nginx не запущен — демо retry timeout:"
    retry 3 1 curl -sf --max-time 1 http://localhost:19999 || echo "Service unreachable after 3 attempts"
fi
