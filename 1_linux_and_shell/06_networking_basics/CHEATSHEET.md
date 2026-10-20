# Сеть в Linux: инструменты — шпаргалка

Подробности и объяснения — в
[linux_networking.md](./01_theory/linux_networking.md). Протоколы и
netfilter — в [2_networking](../../2_networking/).
⚠️ — опасная команда или частая ловушка.

## net-tools → iproute2

| Было (устарело) | Сейчас |
| :--- | :--- |
| `ifconfig` | `ip addr` / `ip -br addr` |
| `ifconfig eth0 up` | `ip link set eth0 up` |
| `route -n` | `ip route` |
| `arp -n` | `ip neigh` |
| `netstat -tlnp` | `ss -tlnp` |
| `netstat -s` | `nstat -az` |

## Интерфейсы и адреса

| Задача | Команда |
| :--- | :--- |
| Адреса коротко | `ip -br addr` |
| Состояние линков, MAC | `ip -br link` |
| Счётчики errors/dropped | `ip -s link show eth0` (подробнее: `ip -s -s link`) |
| Дропы на уровне NIC | `ethtool -S eth0 \| grep -iE 'drop\|miss\|err'` |
| Добавить адрес ⚠️ не переживёт reboot | `sudo ip addr add 10.0.0.5/24 dev eth0` |
| Поднять / опустить ⚠️ по SSH отрежете себя | `sudo ip link set eth0 up\|down` |
| ARP/NDP-кэш | `ip neigh` |
| JSON для скриптов | `ip -j addr \| jq` |

## Маршруты

| Задача | Команда |
| :--- | :--- |
| Таблица маршрутов | `ip route` (IPv6: `ip -6 route`) |
| Куда реально уйдёт пакет и с какого src | `ip route get 8.8.8.8` |
| Policy routing | `ip rule`, `ip route show table all` |
| Добавить маршрут ⚠️ не постоянный | `sudo ip route add 10.10.0.0/16 via 10.0.0.1 dev eth0` |
| Default gateway | `ip route show default` |
| Путь и MTU | `tracepath 1.1.1.1`, `mtr -rwc 50 1.1.1.1` |
| Проверить MTU без фрагментации | `ping -M do -s 1472 <host>` (1472 + 28 = 1500) |

⚠️ Выигрывает самый длинный префикс: `/32` > `/24` > `default` (`/0`).

## Сокеты: ss

| Задача | Команда |
| :--- | :--- |
| Кто слушает TCP-порты | `ss -tlnp` (UDP: `ss -ulnp`) |
| Установленные соединения | `ss -tan state established` |
| Сводка по состояниям | `ss -s` |
| Соединения на порт назначения | `ss -tn 'dport = :443'` |
| Соединения с конкретным хостом | `ss -tn dst 10.0.0.5` |
| RTT, cwnd, ретрансмиты по сокету | `ss -tni` |
| Сколько TIME_WAIT | `ss -tan state time-wait \| wc -l` |
| Эфемерные порты | `sysctl net.ipv4.ip_local_port_range` (дефолт `32768 60999`, ~28k) |

| Флаг | Смысл |
| :--- | :--- |
| `-t` / `-u` / `-x` | TCP / UDP / UNIX |
| `-l` / `-a` | только LISTEN / все |
| `-n` | без резолва имён и портов |
| `-p` | процесс (чужие — только под root) |
| `-i` / `-e` / `-m` | TCP-инфо / расширенное / память сокета |

| Значение | Смысл |
| :--- | :--- |
| TIME_WAIT | 60 с (константа ядра, не sysctl), у того, кто закрыл первым |
| `Cannot assign requested address` | исчерпаны эфемерные порты → keep-alive, пулы, `tcp_tw_reuse=1` |

## DNS на хосте

| Задача | Команда |
| :--- | :--- |
| Порядок источников | `grep ^hosts /etc/nsswitch.conf` |
| Резолв как у приложения (hosts + DNS) | `getent hosts example.com` / `getent ahosts example.com` |
| Прямой DNS-запрос (мимо `/etc/hosts`) | `dig example.com` / `dig @1.1.1.1 example.com +short` |
| Реальные upstream при systemd-resolved | `resolvectl status` |
| Запрос через systemd-resolved | `resolvectl query example.com` |
| Сбросить DNS-кэш | `resolvectl flush-caches` |

⚠️ `/etc/resolv.conf` часто генерируется (systemd-resolved, NetworkManager,
cloud-init) — правьте источник, а не файл. `127.0.0.53` — локальный stub.

## Network namespace и veth

| Задача | Команда |
| :--- | :--- |
| Создать namespace | `sudo ip netns add demo` |
| veth-пара, один конец в ns | `sudo ip link add veth-host type veth peer name veth-demo`<br>`sudo ip link set veth-demo netns demo` |
| Выполнить команду в ns | `sudo ip netns exec demo ip addr` |
| Список именованных ns | `ip netns list` ⚠️ Docker-ns тут не видны |
| Войти в сеть контейнера | `sudo nsenter -t <PID> -n ip addr` |
| Все сетевые ns | `lsns -t net` |
| Удалить | `sudo ip netns del demo` |

Для выхода ns в интернет: default через хост, `net.ipv4.ip_forward=1`, NAT
(MASQUERADE) на хосте.

## tcpdump

| Задача | Команда |
| :--- | :--- |
| DNS-трафик на всех интерфейсах | `sudo tcpdump -i any -nn port 53` |
| Хост и порт | `sudo tcpdump -i eth0 -nn 'tcp port 443 and host 10.0.0.5'` |
| Только SYN | `sudo tcpdump -i eth0 -nn 'tcp[tcpflags] & tcp-syn != 0'` |
| Только RST | `sudo tcpdump -i eth0 -nn 'tcp[tcpflags] & tcp-rst != 0'` |
| Подсеть, кроме SSH | `sudo tcpdump -i eth0 -nn 'net 10.0.0.0/8 and not port 22'` |
| В файл для Wireshark | `sudo tcpdump -i eth0 -nn -c 1000 -w /tmp/cap.pcap port 80` |
| Прочитать файл | `tcpdump -nn -r /tmp/cap.pcap` |
| Содержимое пакетов | `-A` (ASCII) / `-X` (hex+ASCII) |
| В сети контейнера | `sudo nsenter -t <PID> -n tcpdump -i eth0 -nn` |

| Флаг TCP в выводе | Смысл |
| :--- | :--- |
| `[S]` / `[S.]` / `[.]` | SYN / SYN-ACK / ACK |
| `[P.]` / `[F.]` / `[R]` | данные (PSH) / FIN / RST |

⚠️ Без `-nn` tcpdump сам делает DNS-запросы и «зависает» при недоступном
DNS. На проде всегда ограничивайте `-c` и фильтр.

## Netfilter — посмотреть правила

| Задача | Команда |
| :--- | :--- |
| Все правила nftables | `sudo nft list ruleset` |
| Правила iptables(-nft) | `sudo iptables -S`, `sudo iptables -t nat -S` |
| Счётчики | `sudo iptables -L -v -n` |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| `ping` по IP есть, по имени нет | `resolv.conf`, `resolvectl status`, `getent hosts` |
| `dig` работает, приложение — нет | `getent`, `nsswitch.conf`, `/etc/hosts`, `search`/`ndots`, другой ns |
| `Connection refused` | на хосте никто не слушает: `ss -tlnp` (или слушает `127.0.0.1`) |
| Таймаут connect | маршрут (`ip route get`), файрвол, SYN без ответа в `tcpdump` |
| Потери пакетов | `ip -s link`, `ethtool -S`, `nstat -az` |
| `Cannot assign requested address` | TIME_WAIT: `ss -s`, `ip_local_port_range` |

> Проверка: `ip` (`-br`, `-s`, `-j`, `route get`, `rule`), `ss`
> (фильтры `state`, `dport`, `-tni`, `-s`), `nstat`, `resolvectl --help`,
> `getent`, `tracepath`, `mtr`, `ping -M` — локально (iproute2 6.x,
> Fedora 44); все tcpdump-фильтры скомпилированы `tcpdump -y EN10MB -d`
> (tcpdump 4.99.6); не проверено: `ip netns`/`ip addr add`/`ip route add`,
> захват `tcpdump -i`, `nft`/`iptables` (нужен root).
