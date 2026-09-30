#!/usr/bin/env bash
# Smoke тест после деплоя — быстрая проверка что сервис живой
set -euo pipefail

BASE_URL="${1:?Usage: $0 <base_url>}"
MAX_RETRIES=15
RETRY_DELAY=5

echo "=== Smoke tests for $BASE_URL ==="

# Ждать пока сервис поднимется
echo "Waiting for service to be ready..."
for i in $(seq 1 "$MAX_RETRIES"); do
    if curl -sf --max-time 5 "$BASE_URL/health" > /dev/null 2>&1; then
        echo "Service is up (attempt $i)"
        break
    fi
    if (( i == MAX_RETRIES )); then
        echo "ERROR: Service not ready after $((MAX_RETRIES * RETRY_DELAY))s" >&2
        exit 1
    fi
    echo "Attempt $i/$MAX_RETRIES, retrying in ${RETRY_DELAY}s..."
    sleep "$RETRY_DELAY"
done

# Проверки
PASS=0
FAIL=0

check() {
    local name=$1 cmd=$2
    if eval "$cmd" > /dev/null 2>&1; then
        echo "  ✓ $name"
        (( PASS++ ))
    else
        echo "  ✗ $name"
        (( FAIL++ ))
    fi
}

echo "Running smoke tests..."
check "GET /health returns 200"        "curl -sf --max-time 5 $BASE_URL/health"
check "GET /api/version returns 200"   "curl -sf --max-time 5 $BASE_URL/api/version"
check "Response has version field"     "curl -sf $BASE_URL/api/version | jq -e '.version'"
check "Latency < 500ms"                "curl -sf -o /dev/null -w '%{time_total}' $BASE_URL/health | awk '{exit (\$1>0.5)}'"
check "GET /metrics (prometheus)"      "curl -sf --max-time 5 $BASE_URL/metrics | grep -q 'http_requests_total'"

echo ""
echo "Results: $PASS passed, $FAIL failed"

if (( FAIL > 0 )); then
    echo "SMOKE TESTS FAILED" >&2
    exit 1
fi
echo "All smoke tests passed!"
