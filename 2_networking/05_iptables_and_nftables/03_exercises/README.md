# Упражнения — iptables и nftables

Стенд: 🐳 Tier 1 — контейнер с `NET_ADMIN`/`NET_RAW`

```bash
docker run --rm -it --cap-add=NET_ADMIN --cap-add=NET_RAW --name fwlab nicolaka/netshoot bash
```

## 01 — Default-deny с явными разрешениями

**Задача:** Собрать базовый набор правил: default DROP на INPUT, разрешить loopback, established/related, SSH и ICMP echo.

```bash
# TODO: воспроизведи ../02_examples/basic_rules.sh руками, командой за командой
iptables -P INPUT DROP
# ...
iptables -L -v -n --line-numbers
```

## 02 — INPUT vs FORWARD: транзитный трафик

**Задача:** Понять разницу между блокировкой трафика К хосту и ЧЕРЕЗ хост (без реальной настройки роутинга — только прочитать и объяснить).

```
# TODO (письменно): у тебя есть правило iptables -A INPUT -j DROP на сервере,
# который также работает как NAT-шлюз (форвардит трафик из одной сети в другую).
# Заблокирует ли это правило форвардящийся трафик? Почему?
# Какую цепочку нужно использовать вместо/вместе с INPUT?
```

## 03 — DNAT: проброс порта

```bash
# TODO: воспроизведи ../02_examples/dnat_snat_demo.sh
iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 10.0.0.5:80
iptables -t nat -L PREROUTING -v -n
```

## 04 — Тот же результат на nftables

**Задача:** Написать эквивалент правила из упражнения 03 на nftables.

```bash
# TODO:
nft add table ip nat
nft add chain ip nat prerouting '{ type nat hook prerouting priority -100 ; }'
nft add rule ip nat prerouting tcp dport 8080 dnat to 10.0.0.5:80
nft list ruleset
```

## 05 — Обнаружить, что iptables — это на самом деле nftables

**Задача:** Убедиться, что современный `iptables` в этом образе на самом деле транслируется в nftables-правила.

```bash
# Сначала создай правило через iptables (как в упражнении 01 или 03)
iptables -t nat -A PREROUTING -p tcp --dport 9090 -j DNAT --to-destination 10.0.0.9:80

# TODO: теперь посмотри то же самое правило глазами nftables
nft list ruleset
# найди в выводе предупреждение вида "table ip nat is managed by iptables-nft, do not touch!"
# и chain с ИМЕНЕМ В ВЕРХНЕМ РЕГИСТРЕ (PREROUTING) — это и есть след iptables-совместимости
```
