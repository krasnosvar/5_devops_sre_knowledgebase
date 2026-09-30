#!/usr/bin/env bash
# Демонстрация: наблюдать TCP handshake и состояние сокетов вживую

echo "=== Слушающие сокеты на хосте ==="
ss -tlnp 2>/dev/null || ss -tln

echo -e "\n=== Активные (ESTABLISHED) соединения ==="
ss -tan state established | head -10

echo -e "\n=== Полуоткрытые соединения (если есть — признак проблем) ==="
ss -tan state syn-sent
ss -tan state syn-recv

echo -e "\n=== Захват SYN/SYN-ACK/ACK для конкретного хоста (нужен root) ==="
echo "Пример (запустить в отдельном терминале, затем сделать curl к этому же хосту):"
echo "  sudo tcpdump -i any -n 'tcp[tcpflags] & (tcp-syn|tcp-ack) != 0' -c 6 host example.com"

echo -e "\n=== Текущий MTU интерфейсов ==="
ip -o link show | awk -F': ' '{print $2}' | while read -r iface; do
    mtu=$(ip link show "$iface" | grep -oP 'mtu \K[0-9]+')
    echo "  $iface: MTU=$mtu"
done

echo -e "\n=== Проверка Path MTU без фрагментации ==="
echo "ping -M do -s 1472 8.8.8.8   # 1472+28(IP/ICMP)=1500, DF-бит выставлен"
