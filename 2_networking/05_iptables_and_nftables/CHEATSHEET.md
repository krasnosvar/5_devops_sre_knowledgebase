# iptables и nftables — шпаргалка

Подробности и объяснения — в
[iptables_and_nftables.md](./01_theory/iptables_and_nftables.md). ⚠️ —
опасная команда или частая ловушка.

⚠️ На удалённом хосте правила меняют только с «страховкой»: сначала
разрешить `ESTABLISHED,RELATED` и SSH, потом `DROP`/policy; держать открытую
вторую сессию или отложенный откат (`iptables-apply`, `at now + 5 min`).

## Путь пакета (цепочки)

| Пакет | Цепочки |
| :--- | :--- |
| Входящий, этому хосту | `PREROUTING` → routing → `INPUT` → приложение |
| Транзитный (роутер, Docker, k8s) | `PREROUTING` → routing → `FORWARD` → `POSTROUTING` |
| Исходящий от процесса | routing → `OUTPUT` → `POSTROUTING` |

| Таблица | Назначение | Цепочки |
| :--- | :--- | :--- |
| `raw` | до conntrack (`NOTRACK`) | `PREROUTING`, `OUTPUT` |
| `mangle` | правка пакета, метки | все |
| `nat` | DNAT / SNAT / MASQUERADE | `PREROUTING`, `OUTPUT`, `POSTROUTING` (+`INPUT`) |
| `filter` (по умолчанию) | ACCEPT / DROP / REJECT | `INPUT`, `FORWARD`, `OUTPUT` |

## iptables

| Задача | Команда |
| :--- | :--- |
| Правила filter с номерами и счётчиками | `iptables -L -v -n --line-numbers` |
| Правила NAT | `iptables -t nat -L -v -n` |
| В формате команд (удобно для diff) | `iptables -S` / `iptables -t nat -S` |
| Дамп / восстановление всего набора | `iptables-save > rules.v4` / `iptables-restore < rules.v4` |
| Добавить в конец | `iptables -A INPUT -p tcp --dport 22 -j ACCEPT` |
| Вставить первым (порядок важен) | `iptables -I INPUT 1 -p tcp --dport 22 -j ACCEPT` |
| Удалить по номеру ⚠️ | `iptables -D INPUT 5` |
| Есть ли правило (код 0/1) | `iptables -C INPUT -p tcp --dport 22 -j ACCEPT` |
| Stateful-база | `iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT` |
| Loopback | `iptables -A INPUT -i lo -j ACCEPT` |
| Policy DROP ⚠️ (без правил выше — потеря SSH) | `iptables -P INPUT DROP` |
| Сбросить все правила ⚠️ (policy остаются!) | `iptables -F` |
| Логировать перед DROP | `iptables -A INPUT -j LOG --log-prefix "IN-DROP: "` |
| Обнулить счётчики | `iptables -Z` |
| Какой бэкенд | `iptables -V` → `(nf_tables)` или `(legacy)` |

| NAT | Команда |
| :--- | :--- |
| Port forwarding (DNAT) | `iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 10.0.0.5:80` |
| SNAT на динамический IP | `iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE` |
| SNAT на статический IP | `iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o eth0 -j SNAT --to-source 203.0.113.10` |
| Не трекать (DNS-сервер под нагрузкой) | `iptables -t raw -A PREROUTING -p udp --dport 53 -j NOTRACK` |
| Для DNAT-транзита нужен форвардинг | `sysctl -w net.ipv4.ip_forward=1` + `FORWARD` ACCEPT |

## conntrack

| Задача | Команда |
| :--- | :--- |
| Таблица соединений | `conntrack -L` (пакет `conntrack-tools`) |
| Число записей / лимит | `conntrack -C` / `sysctl net.netfilter.nf_conntrack_max` |
| Сейчас записей (без утилиты) | `cat /proc/sys/net/netfilter/nf_conntrack_count` |
| Статистика (drop, insert_failed) | `conntrack -S` |
| Удалить записи для IP ⚠️ | `conntrack -D -s 10.0.0.5` |
| Признак переполнения | `dmesg \| grep 'nf_conntrack: table full'` |
| Поднять лимит | `sysctl -w net.netfilter.nf_conntrack_max=262144` |

## nftables

| Задача | Команда |
| :--- | :--- |
| Весь набор правил | `nft list ruleset` |
| С handle'ами (для удаления) | `nft -a list chain inet filter input` |
| Проверить файл без применения | `nft -c -f rules.nft` |
| Применить атомарно | `nft -f rules.nft` |
| Создать таблицу и цепочку | `nft add table inet filter`<br>`nft add chain inet filter input '{ type filter hook input priority filter; policy accept; }'` |
| Добавить правило в конец / в начало | `nft add rule inet filter input tcp dport 22 accept` / `nft insert rule ...` |
| Удалить правило ⚠️ | `nft delete rule inet filter input handle 12` |
| Добавить элемент в set | `nft add element inet filter allowed_ssh '{ 172.16.0.0/12 }'` |
| Очистить всё ⚠️ | `nft flush ruleset` |
| Перевести iptables-правила | `iptables-translate -A INPUT -p tcp --dport 22 -j ACCEPT` |

```nft
flush ruleset
table inet filter {
  set allowed_ssh {
    type ipv4_addr
    flags interval
    elements = { 10.0.0.0/8, 192.168.1.0/24 }
  }
  chain input {
    type filter hook input priority filter; policy drop;
    ct state established,related accept
    ct state invalid drop
    iif lo accept
    ip saddr @allowed_ssh tcp dport 22 accept
    tcp dport { 80, 443 } accept
    icmp type echo-request limit rate 5/second accept
    counter log prefix "nft-drop: " drop
  }
}
table ip nat {
  chain prerouting {
    type nat hook prerouting priority dstnat;
    tcp dport 8080 dnat to 10.0.0.5:80
  }
  chain postrouting {
    type nat hook postrouting priority srcnat;
    oifname "eth0" masquerade
  }
}
```

## iptables vs nftables

| | iptables | nftables |
| :--- | :--- | :--- |
| Семейства | отдельные `iptables`/`ip6tables`/`arptables`/`ebtables` | одна `nft`, семейство `inet` = v4+v6 |
| Применение | по одному правилу | атомарно файлом |
| Множества | через `ipset` | встроенные `set`/`map` |
| Сегодня | обычно обёртка `iptables-nft` над nf_tables | нативный интерфейс |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| `DROP` в `INPUT`, а транзит идёт | транзит — в `FORWARD` |
| Правило есть, но не срабатывает | порядок: выше стоит `ACCEPT`; `-L --line-numbers`, счётчики `-v` |
| DNAT есть, ответа нет | нет SNAT/маршрута назад, `ip_forward=0`, `FORWARD` DROP |
| Новые соединения тихо теряются на NAT-шлюзе | `nf_conntrack_count` ≈ `nf_conntrack_max` |
| Правила из `iptables -L` не видны в `nft` (или наоборот) | смешаны `legacy` и `nf_tables` бэкенды: `iptables -V` |
| Правила пропали после ребута | не сохранены: `iptables-save`/`nftables.service` с `/etc/nftables.conf` |

> Проверка: команды iptables (v1.8.11) и весь nft-сниппет (`nft -c`, затем
> `nft -f`, nftables 1.1.6) выполнены в одноразовом netns `unshare -rn`, хост
> не тронут; не проверено: `conntrack` (нет `conntrack-tools`),
> `iptables-apply`.
