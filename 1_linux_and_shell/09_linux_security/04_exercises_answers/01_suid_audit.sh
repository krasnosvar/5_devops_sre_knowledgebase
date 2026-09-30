#!/usr/bin/env bash
# Ответ: упражнение 01 — SUID/SGID аудит
# Демонстрирует: поиск SUID-бинарников и замену SUID на точечную capability

echo "=== Все SUID/SGID бинарники ==="
find / -xdev \( -perm -4000 -o -perm -2000 \) -type f 2>/dev/null

echo -e "\n=== Пример: у ping capabilities вместо SUID (современные дистрибутивы) ==="
PING_BIN=$(command -v ping)
echo "Бинарник: $PING_BIN"
ls -l "$PING_BIN"
getcap "$PING_BIN"
# Если SUID снят, а capability не выставлена — ping не сможет создать raw socket.
# Правильная замена SUID на capability (не требует полного root):
#   sudo setcap cap_net_raw+ep "$PING_BIN"
#   sudo chmod u-s "$PING_BIN"

echo -e "\n=== Типичные 'подозрительные' SUID из-за которых стоит насторожиться ==="
echo "Если находишь SUID на find, vim, python, perl, awk, nmap — это почти всегда"
echo "означает, что кто-то намеренно оставил бэкдор для privilege escalation"
echo "(классические GTFOBins-техники: 'find . -exec /bin/sh \; -quit')."
for bin in find vim python python3 perl awk nmap; do
    path=$(command -v "$bin" 2>/dev/null)
    [ -n "$path" ] && [ -u "$path" ] && echo "  ПОДОЗРИТЕЛЬНО: $path имеет SUID-бит"
done
echo "(если строк выше нет — на этом хосте таких бэкдоров не найдено)"
