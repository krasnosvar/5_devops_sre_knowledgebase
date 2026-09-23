#!/usr/bin/env bash
# Ответ: упражнение 01 — идемпотентный setup скрипт
set -euo pipefail

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# Идемпотентное создание директории
mkdir -p /opt/myapp
log "Directory /opt/myapp: OK"

# Идемпотентное добавление строки в файл
ENTRY='export PATH=$PATH:/opt/myapp/bin'
grep -qxF "$ENTRY" ~/.bashrc || echo "$ENTRY" >> ~/.bashrc
log "PATH entry: OK"

# Идемпотентная установка пакета
if ! command -v curl &>/dev/null; then
    apt-get install -y curl 2>/dev/null || dnf install -y curl 2>/dev/null
    log "curl: installed"
else
    log "curl: already present"
fi

# Идемпотентный systemd сервис
if ! systemctl is-enabled myapp &>/dev/null 2>&1; then
    # создать unit если не существует
    cat > /tmp/myapp.service << 'EOF'
[Unit]
Description=My App (test)
[Service]
ExecStart=/bin/sleep infinity
[Install]
WantedBy=multi-user.target
EOF
    log "systemd unit: would install (skipping in demo)"
else
    log "systemd unit: already enabled"
fi

log "Setup complete — safe to run multiple times"
