#!/usr/bin/env bash
# Ответ: упражнение 01 — идемпотентный setup-скрипт.
# Запуск: sudo bash 01_idempotent_setup.sh (дважды; второй раз — только
# "already done").
set -euo pipefail

APP_DIR=/opt/myapp
HOSTS_LINE='10.0.0.10 myapp.internal'
PACKAGE=jq

log() { echo "[$(date '+%H:%M:%S')] $*"; }

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: нужен root (запустите через sudo)" >&2
    exit 1
fi

# 1. Директория: проверяем явно, чтобы честно сообщить, что изменилось
if [[ -d $APP_DIR ]]; then
    log "$APP_DIR: already done"
else
    mkdir -p "$APP_DIR"
    log "$APP_DIR: created"
fi

# 2. Строка в /etc/hosts: -x — совпадение всей строки, -F — без regex
if grep -qxF "$HOSTS_LINE" /etc/hosts; then
    log "/etc/hosts entry: already done"
else
    echo "$HOSTS_LINE" >> /etc/hosts
    log "/etc/hosts entry: added"
fi

# 3. Пакет: ставим только если бинарника нет; менеджер пакетов выбираем
# явно и падаем, если ни один не найден
if command -v "$PACKAGE" >/dev/null; then
    log "$PACKAGE: already done"
elif command -v apt-get >/dev/null; then
    apt-get update -qq
    apt-get install -y -qq "$PACKAGE"
    log "$PACKAGE: installed (apt)"
elif command -v dnf >/dev/null; then
    dnf install -y -q "$PACKAGE"
    log "$PACKAGE: installed (dnf)"
else
    echo "ERROR: не найден ни apt-get, ни dnf — установите $PACKAGE вручную" >&2
    exit 1
fi

log "Setup complete — safe to run multiple times"
