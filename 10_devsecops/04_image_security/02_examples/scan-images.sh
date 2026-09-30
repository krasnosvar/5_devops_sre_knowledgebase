#!/usr/bin/env bash
# Сканирование образов на CVE с помощью Trivy

set -euo pipefail

echo "=== Trivy — сканирование образов ==="

# Базовое сканирование
scan_image() {
    local image=$1
    echo -e "\n--- $image ---"
    trivy image \
        --severity HIGH,CRITICAL \
        --ignore-unfixed \
        --no-progress \
        "$image" 2>/dev/null | grep -E "CRITICAL|HIGH|Total:" | tail -5
}

# Сравнить базовые образы
for img in ubuntu:22.04 ubuntu:24.04 debian:12-slim python:3.12-slim alpine:3.19; do
    scan_image "$img"
done

echo -e "\n=== Сканирование локального образа ==="
if docker images | grep -q myapp; then
    trivy image \
        --exit-code 1 \
        --severity CRITICAL \
        --ignore-unfixed \
        myapp:latest \
        && echo "No CRITICAL vulnerabilities" \
        || echo "CRITICAL vulnerabilities found!"
fi

echo -e "\n=== Сканирование зависимостей в коде ==="
if [[ -f requirements.txt ]]; then
    trivy fs --scanners vuln . --severity HIGH,CRITICAL
fi

echo -e "\n=== SBOM генерация (Software Bill of Materials) ==="
if command -v syft &>/dev/null; then
    syft ubuntu:22.04 -o spdx-json > /tmp/ubuntu-sbom.json 2>/dev/null
    echo "SBOM сгенерирован: /tmp/ubuntu-sbom.json"
    echo "Компонентов: $(jq '.packages | length' /tmp/ubuntu-sbom.json)"

    # Проверить SBOM на CVE
    grype sbom:/tmp/ubuntu-sbom.json --severity critical 2>/dev/null | head -10 || true
else
    echo "(syft не установлен — brew install syft)"
fi
