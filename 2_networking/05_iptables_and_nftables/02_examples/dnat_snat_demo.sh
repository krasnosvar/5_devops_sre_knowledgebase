#!/usr/bin/env bash
# Демонстрация: DNAT (port forwarding) + SNAT/MASQUERADE
set -e

echo "=== DNAT: проброс порта 8080 -> внутренний сервис 10.0.0.5:80 ==="
iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 10.0.0.5:80
iptables -t nat -L PREROUTING -v -n

echo -e "\n=== MASQUERADE: подмена source IP для исходящего трафика через eth0 ==="
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -t nat -L POSTROUTING -v -n

echo -e "\n=== nftables-эквивалент того же самого ==="
cat <<'EOF'
nft add table ip nat
nft add chain ip nat prerouting { type nat hook prerouting priority -100 \; }
nft add chain ip nat postrouting { type nat hook postrouting priority 100 \; }
nft add rule ip nat prerouting tcp dport 8080 dnat to 10.0.0.5:80
nft add rule ip nat postrouting oifname "eth0" masquerade
EOF
