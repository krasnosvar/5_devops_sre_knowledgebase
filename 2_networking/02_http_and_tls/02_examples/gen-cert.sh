#!/usr/bin/env bash
# Генерирует self-signed сертификат для локальной лабы (NOT for production)
set -euo pipefail
mkdir -p certs
openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
  -keyout certs/server.key -out certs/server.crt \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost"
echo "Готово: certs/server.crt, certs/server.key"
