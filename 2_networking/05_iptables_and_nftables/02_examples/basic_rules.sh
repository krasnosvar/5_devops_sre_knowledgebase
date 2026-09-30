#!/usr/bin/env bash
# Демонстрация: базовые iptables-правила (filter + NAT), conntrack
set -e

echo "=== Текущие правила filter ==="
iptables -L -v -n --line-numbers

echo -e "\n=== Базовый набор: default-deny + разрешить established + ssh ==="
iptables -P INPUT DROP
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

echo -e "\n=== Итоговые правила ==="
iptables -L -v -n --line-numbers

echo -e "\n=== Таблица conntrack ==="
conntrack -L 2>/dev/null || echo "(conntrack CLI не установлен в этом образе)"

echo -e "\n=== Лимит conntrack ==="
cat /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null || echo "(недоступно без соответствующих прав)"
