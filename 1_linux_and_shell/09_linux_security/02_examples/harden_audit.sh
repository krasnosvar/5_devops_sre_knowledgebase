#!/usr/bin/env bash
# Быстрый аудит security-настроек Linux-хоста
# Только чтение — ничего не меняет и не требует root (часть проверок будет
# менее полной без sudo, но скрипт не упадёт)

echo "=== SUID/SGID бинарники ==="
echo "Кандидаты на privilege escalation, если версия уязвима или права избыточны:"
find / -xdev \( -perm -4000 -o -perm -2000 \) -type f 2>/dev/null | head -20

echo -e "\n=== sudoers: опасные wildcard-правила ==="
if [ -r /etc/sudoers ]; then
    grep -En "NOPASSWD:\s*ALL|ALL=\(ALL\)\s*ALL" /etc/sudoers /etc/sudoers.d/* 2>/dev/null \
        || echo "Явных NOPASSWD:ALL правил не найдено"
else
    echo "(нет доступа на чтение /etc/sudoers — запустите с sudo для полной проверки)"
fi

echo -e "\n=== sshd_config: базовый hardening-чеклист ==="
SSHD_CONFIG=/etc/ssh/sshd_config
if [ -r "$SSHD_CONFIG" ]; then
    for opt in PermitRootLogin PasswordAuthentication MaxAuthTries X11Forwarding; do
        val=$(grep -Ei "^\s*${opt}\s+" "$SSHD_CONFIG" | tail -1)
        echo "  ${opt}: ${val:-(не задано, используется дефолт дистрибутива)}"
    done
else
    echo "(нет доступа на чтение $SSHD_CONFIG)"
fi

echo -e "\n=== MAC: SELinux / AppArmor ==="
if command -v getenforce >/dev/null 2>&1; then
    echo "SELinux: $(getenforce)"
elif command -v aa-status >/dev/null 2>&1; then
    aa-status --enabled 2>/dev/null && echo "AppArmor: enabled" || echo "AppArmor: disabled"
    aa-status 2>/dev/null | grep -E "profiles are in (enforce|complain) mode" || true
else
    echo "Ни SELinux, ни AppArmor не обнаружены в PATH"
fi

echo -e "\n=== auditd ==="
if systemctl is-active auditd >/dev/null 2>&1; then
    echo "auditd активен"
    command -v auditctl >/dev/null 2>&1 && sudo -n auditctl -l 2>/dev/null | head -10
else
    echo "auditd не запущен (systemctl status auditd)"
fi

echo -e "\n=== Ключевые sysctl hardening-параметры ==="
for param in kernel.randomize_va_space kernel.yama.ptrace_scope \
             net.ipv4.conf.all.rp_filter net.ipv4.conf.all.accept_redirects \
             net.ipv4.icmp_echo_ignore_broadcasts; do
    val=$(sysctl -n "$param" 2>/dev/null)
    echo "  ${param} = ${val:-(недоступно в этом окружении, например контейнер без CAP_NET_ADMIN)}"
done

echo -e "\n=== Готово. Сравните вывод с чеклистом в 01_theory/linux_security.md ==="
