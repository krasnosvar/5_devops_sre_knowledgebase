#!/usr/bin/env bash
# Ответ: упражнение 02 — функция retry с экспоненциальным backoff.
# Использование: bash 02_retry_with_backoff.sh [URL]
#   (по умолчанию http://localhost:8080/health)
# Проверка: в соседнем терминале через ~5 секунд поднять сервис, например
#   mkdir -p /tmp/www && touch /tmp/www/health \
#     && python3 -m http.server 8080 -d /tmp/www
set -euo pipefail

# retry <попыток> <начальная задержка, с> <команда...>
retry() {
    local max=$1 delay=$2
    shift 2
    local attempt=1
    while true; do
        if "$@"; then
            echo "Attempt $attempt/$max succeeded" >&2
            return 0
        fi
        if (( attempt >= max )); then
            echo "Attempt $attempt/$max failed, giving up: $*" >&2
            return 1
        fi
        echo "Attempt $attempt/$max failed, retrying in ${delay}s..." >&2
        sleep "$delay"
        attempt=$(( attempt + 1 ))
        delay=$(( delay * 2 > 60 ? 60 : delay * 2 ))   # потолок 60 с
    done
}

URL=${1:-http://localhost:8080/health}

# -s тихо, -f ненулевой код на HTTP >= 400, --max-time не даёт повиснуть
retry 5 2 curl -sf --max-time 3 -o /dev/null "$URL"
echo "Service $URL is up"
