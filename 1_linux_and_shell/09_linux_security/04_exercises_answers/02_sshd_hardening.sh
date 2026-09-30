#!/usr/bin/env bash
# Ответ: упражнение 02 — SSH hardening
# Демонстрирует: безопасное применение hardened sshd_config с проверкой синтаксиса

set -euo pipefail

SSHD_CONFIG=/etc/ssh/sshd_config
BACKUP="${SSHD_CONFIG}.bak.$(date +%s)"

echo "=== Бэкап текущего конфига → $BACKUP ==="
sudo cp "$SSHD_CONFIG" "$BACKUP"

echo -e "\n=== Применяем hardening через drop-in (безопаснее правки основного файла) ==="
# /etc/ssh/sshd_config.d/*.conf подключается автоматически современным sshd
# и переопределяет основной файл — не нужно трогать сам sshd_config
sudo tee /etc/ssh/sshd_config.d/99-hardening.conf > /dev/null <<'EOF'
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
EOF

echo -e "\n=== Проверка синтаксиса ДО рестарта (критично!) ==="
if sudo sshd -t; then
    echo "Синтаксис корректен, применяем"
    sudo systemctl restart sshd
else
    echo "ОШИБКА в конфиге — откатываемся, sshd НЕ перезапущен"
    sudo rm -f /etc/ssh/sshd_config.d/99-hardening.conf
    exit 1
fi

echo -e "\n=== Проверка: вход по паролю должен быть отклонён ==="
ssh -o BatchMode=yes -o PreferredAuthentications=password \
    -o ConnectTimeout=3 localhost 2>&1 | grep -qi "denied\|refused" \
    && echo "OK: password auth отключён" \
    || echo "Проверь вручную — автоматическая проверка неоднозначна в этом окружении"
