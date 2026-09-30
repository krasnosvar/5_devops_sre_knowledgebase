#!/usr/bin/env bash
# Ответ: упражнение 05 — sysctl hardening
# Демонстрирует: постоянное применение kernel hardening параметров

set -euo pipefail

CONF=/etc/sysctl.d/99-hardening.conf

sudo tee "$CONF" > /dev/null <<'EOF'
# ASLR — рандомизация адресного пространства (обязательно)
kernel.randomize_va_space = 2

# Запрет ptrace одним процессом другого (кроме своих прямых потомков)
kernel.yama.ptrace_scope = 1

# Защита от IP spoofing
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Не принимать ICMP redirect (защита от MITM)
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0

# Игнорировать broadcast ICMP (защита от Smurf-атак)
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Не пересылать пакеты, если это не роутер
net.ipv4.ip_forward = 0
EOF

echo "=== Применяем ==="
sudo sysctl --system

echo -e "\n=== Проверка ==="
for param in kernel.randomize_va_space kernel.yama.ptrace_scope \
             net.ipv4.conf.all.rp_filter net.ipv4.icmp_echo_ignore_broadcasts; do
    echo "  ${param} = $(sysctl -n "$param")"
done

echo -e "\n=== Бонус: демонстрация ptrace_scope=1 в действии ==="
sleep 300 &
BG_PID=$!
echo "Фоновый процесс sleep запущен как PID $BG_PID (не потомок текущего скрипта после отключения от shell)"
if strace -p "$BG_PID" -e trace=none 2>&1 | grep -qi "operation not permitted"; then
    echo "OK: ptrace заблокирован ядром, как и ожидалось при ptrace_scope=1"
else
    echo "ptrace прошёл — либо ptrace_scope=0, либо процесс всё же считается потомком"
fi
kill "$BG_PID" 2>/dev/null || true
