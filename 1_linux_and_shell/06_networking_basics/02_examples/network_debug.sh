#!/usr/bin/env bash
# Шпаргалка по отладке сети Linux

echo "=== Сетевые интерфейсы ==="
ip addr show
echo ""
ip -s link show   # статистика

echo -e "\n=== Маршрутизация ==="
ip route show
echo "Маршрут до 8.8.8.8:"
ip route get 8.8.8.8

echo -e "\n=== Открытые порты ==="
ss -tlnp   # TCP listening

echo -e "\n=== Активные соединения ==="
ss -tnp | head -20

echo -e "\n=== conntrack — таблица соединений ==="
if command -v conntrack &>/dev/null; then
    conntrack -L 2>/dev/null | head -10
    echo "Всего соединений: $(conntrack -L 2>/dev/null | wc -l)"
else
    echo "(conntrack не установлен: dnf install conntrack-tools)"
fi

echo -e "\n=== iptables правила ==="
iptables -L -n --line-numbers 2>/dev/null | head -30 \
    || echo "(требуется root)"

echo -e "\n=== veth пары (Docker) ==="
ip link show type veth 2>/dev/null | head -20

echo -e "\n=== DNS проверка ==="
# Резолвинг
host google.com 2>/dev/null || nslookup google.com 2>/dev/null | head -5
# Время TTL
dig google.com +short +ttl 2>/dev/null | head -3

echo -e "\n=== Traceroute ==="
traceroute -n -w 1 -q 1 8.8.8.8 2>/dev/null | head -5 \
    || echo "(traceroute недоступен)"
