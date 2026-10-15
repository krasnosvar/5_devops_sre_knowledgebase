# Сеть в Linux: инструменты iproute2, сокеты, netns и tcpdump

Это вводная тема про **инструменты Linux** для работы с сетью: как
посмотреть интерфейсы, маршруты, сокеты, откуда берётся DNS-резолвинг и
как собрать изолированную сеть из network namespace и veth. Протоколы
по-настоящему разбираются в разделе [2_networking](../../../2_networking/):
TCP/UDP и handshake — [00_osi_and_tcpip](../../../2_networking/00_osi_and_tcpip/),
DNS — [01_dns](../../../2_networking/01_dns/), TLS —
[02_http_and_tls](../../../2_networking/02_http_and_tls/), балансировка —
[03_load_balancing](../../../2_networking/03_load_balancing/), netfilter,
NAT и conntrack — [05_iptables_and_nftables](../../../2_networking/05_iptables_and_nftables/).

## Содержание
1. [Сетевой стек Linux и iproute2](#1-сетевой-стек-linux-и-iproute2)
2. [Маршрутизация: ip route](#2-маршрутизация-ip-route)
3. [Сокеты: ss и состояние TIME_WAIT](#3-сокеты-ss-и-состояние-time_wait)
4. [Разрешение имён на хосте: /etc/hosts, nsswitch, resolv.conf](#4-разрешение-имён-на-хосте-etchosts-nsswitch-resolvconf)
5. [Network namespaces и veth-пары](#5-network-namespaces-и-veth-пары)
6. [tcpdump: базовый захват трафика](#6-tcpdump-базовый-захват-трафика)
7. [Netfilter — коротко и куда дальше](#7-netfilter--коротко-и-куда-дальше)
8. [Типовые вопросы на собеседовании (Interview Q&A)](#8-типовые-вопросы-на-собеседовании-interview-qa)

---

## 1. Сетевой стек Linux и iproute2

Сетевой стек Linux живёт в ядре. Когда сетевая карта (NIC) получает кадр,
она кладёт его в кольцевой буфер и сигнализирует прерыванием; ядро
разбирает L2 (Ethernet), L3 (IP), L4 (TCP/UDP) и отдаёт полезную нагрузку
приложению через сокет. Приложение видит только сокет — всё остальное
делает ядро.

Управляет этим из user space пакет **iproute2** (общается с ядром через
netlink). Устаревшие `ifconfig`, `route`, `netstat` из net-tools на
современных системах часто даже не установлены.

```bash
ip -br addr          # интерфейсы и адреса, коротко
ip -br link          # состояние интерфейсов (UP/DOWN), MAC
ip -s link show eth0 # счётчики: байты, пакеты, errors, dropped
ip neigh             # ARP/NDP-кэш: IP соседа -> MAC
```

`dropped` и `errors` в `ip -s link` — первое, куда смотреть при «сеть
теряет пакеты»; глубокий разбор дропов — в
[11_troubleshooting](../../11_troubleshooting/01_theory/linux_troubleshooting.md).

## 2. Маршрутизация: ip route

Для каждого исходящего пакета ядро выбирает маршрут с **самым длинным
совпадающим префиксом** (longest prefix match): `/32` важнее `/24`, а
`default` (`0.0.0.0/0`) срабатывает, только если ничего точнее нет.

```bash
ip route
# 10.10.1.0/24 dev eth1 proto kernel scope link src 10.10.1.5
# default via 192.168.1.1 dev eth0

ip route get 10.10.1.100   # ... dev eth1 src 10.10.1.5  (сосед, без шлюза)
ip route get 8.8.8.8       # ... via 192.168.1.1 dev eth0 (через default)
```

`ip route get` — самый честный способ ответить «куда ядро отправит этот
пакет и с какого адреса»: он проходит реальную логику выбора маршрута,
включая policy routing (`ip rule`). Подробнее о таблицах маршрутизации и
динамической маршрутизации — в
[2_networking/04_bgp_and_routing](../../../2_networking/04_bgp_and_routing/).

## 3. Сокеты: ss и состояние TIME_WAIT

`ss` показывает сокеты ядра, запрашивая их через netlink (`sock_diag`), а
не разбирая текстовые `/proc/net/tcp`, как `netstat`, — поэтому он быстрый
даже на хосте с сотнями тысяч соединений.

```bash
ss -tlnp                       # TCP, LISTEN, без резолва, с процессом
ss -tan state established      # активные соединения
ss -s                          # сводка по состояниям
ss -tan state time-wait | wc -l
sysctl net.ipv4.ip_local_port_range   # 32768 60999 — эфемерные порты
```

**TIME_WAIT** — состояние, в которое переходит сторона, **первой**
закрывшая TCP-соединение. В Linux оно длится 60 секунд (константа ядра,
не sysctl) и защищает от того, чтобы запоздавшие пакеты старого
соединения попали в новое с той же четвёркой адресов/портов. Проблема
возникает у клиента, который открывает тысячи коротких соединений к одному
бэкенду и сам их закрывает (например, reverse proxy без keep-alive):
эфемерные порты (~28 тысяч по умолчанию) заняты TIME_WAIT, и `connect()`
падает с `Cannot assign requested address`. Лечение — keep-alive и пулы
соединений; `net.ipv4.tcp_tw_reuse=1` разрешает переиспользовать
TIME_WAIT-сокет для исходящих соединений. Сам handshake и состояния TCP —
в [2_networking/00_osi_and_tcpip](../../../2_networking/00_osi_and_tcpip/).

## 4. Разрешение имён на хосте: /etc/hosts, nsswitch, resolv.conf

Резолвинг имён делает **не ядро**, а библиотека в процессе (glibc
`getaddrinfo()`). Порядок источников задаёт `/etc/nsswitch.conf`:

```bash
grep ^hosts /etc/nsswitch.conf
# hosts: files dns           -> сначала /etc/hosts, потом DNS
cat /etc/resolv.conf
# nameserver 127.0.0.53      -> локальный stub systemd-resolved
# search corp.internal

getent hosts example.com     # резолв ровно так, как его сделает приложение
resolvectl status            # реальные upstream DNS при systemd-resolved
```

`/etc/resolv.conf` часто генерируется (`systemd-resolved`, NetworkManager,
cloud-init), поэтому ручные правки перезаписываются — менять надо
источник. `dig`/`nslookup` ходят в DNS напрямую и **игнорируют**
`/etc/hosts` и nsswitch, а `getent` повторяет путь приложения: если `dig`
отвечает, а приложение — нет, сравните с `getent`. Как устроен сам DNS —
в [2_networking/01_dns](../../../2_networking/01_dns/).

## 5. Network namespaces и veth-пары

Network namespace — отдельная копия сетевого стека: свои интерфейсы,
маршруты, правила netfilter, сокеты. Это то, на чём стоит сеть
контейнеров (см. [02_cgroups_and_namespaces](../../02_cgroups_and_namespaces/)).
**veth** — виртуальный «кабель» из двух интерфейсов: пакет, отправленный в
один конец, выходит из другого. Один конец кладут в namespace, второй
оставляют на хосте (или в bridge) — так Docker и CNI-плагины подключают
контейнеры.

```bash
sudo ip netns add demo
sudo ip link add veth-host type veth peer name veth-demo
sudo ip link set veth-demo netns demo

sudo ip addr add 10.200.0.1/24 dev veth-host
sudo ip link set veth-host up
sudo ip netns exec demo ip addr add 10.200.0.2/24 dev veth-demo
sudo ip netns exec demo ip link set veth-demo up
sudo ip netns exec demo ip link set lo up

ping -c1 10.200.0.2                      # хост -> namespace
sudo ip netns exec demo ip route         # в namespace только своя /24
sudo ip netns exec demo ping -c1 8.8.8.8 # Network is unreachable: нет default

sudo ip netns del demo   # veth-пару ядро удалит вместе с namespace (асинхронно)
```

Чтобы такой namespace вышел в интернет, нужны default-маршрут через
`10.200.0.1`, `net.ipv4.ip_forward=1` и NAT (MASQUERADE) на хосте — ровно
то, что делает Docker для bridge-сети; NAT разбирается в
[2_networking/05_iptables_and_nftables](../../../2_networking/05_iptables_and_nftables/).
В namespace контейнера можно зайти с хоста без утилит внутри образа:
`sudo nsenter -t <PID> -n ip addr`.

## 6. tcpdump: базовый захват трафика

`tcpdump` копирует пакеты с интерфейса (через `AF_PACKET`-сокет и
BPF-фильтр в ядре) и показывает заголовки. Фильтр выполняется в ядре, так
что узкий фильтр дёшев даже на загруженном хосте.

```bash
sudo tcpdump -i any -nn port 53                  # DNS-запросы хоста
sudo tcpdump -i eth0 -nn 'tcp port 443 and host 10.0.0.5'
sudo tcpdump -i eth0 -nn 'tcp[tcpflags] & tcp-syn != 0'   # только SYN
sudo tcpdump -i eth0 -nn -c 100 -w /tmp/cap.pcap port 80  # в файл
tcpdump -nn -r /tmp/cap.pcap | head                       # прочитать
```

`-nn` отключает резолв имён и портов (иначе tcpdump сам генерирует
DNS-трафик и тормозит), `-i any` слушает все интерфейсы, `-c` ограничивает
число пакетов, `-w` пишет pcap для Wireshark. Чтение флагов TCP в выводе
(`[S]`, `[S.]`, `[.]`, `[F.]`, `[R]`) опирается на знание handshake — см.
[2_networking/00_osi_and_tcpip](../../../2_networking/00_osi_and_tcpip/).

## 7. Netfilter — коротко и куда дальше

**Netfilter** — набор хуков в сетевом стеке ядра, через которые проходят
пакеты; `iptables` и `nftables` — user space утилиты, вешающие на эти
хуки правила (фильтрация, NAT). Модуль **conntrack** запоминает
соединения, благодаря чему файрвол stateful. Цепочки
(PREROUTING/INPUT/FORWARD/OUTPUT/POSTROUTING), DNAT vs SNAT, conntrack и
переход на nftables подробно разобраны в
[2_networking/05_iptables_and_nftables](../../../2_networking/05_iptables_and_nftables/).
Для этой темы достаточно уметь посмотреть текущие правила:

```bash
sudo nft list ruleset | head -40
sudo iptables -S | head -20      # на системах с iptables(-nft)
```

---

## 8. Типовые вопросы на собеседовании (Interview Q&A)

**1. Что такое состояние TCP `TIME_WAIT` и почему при большой нагрузке на
балансировщик оно становится проблемой?**
*Ответ:* В `TIME_WAIT` (в Linux — 60 секунд) переходит сторона, которая
**первой** закрыла соединение. Это защита от того, чтобы опоздавшие пакеты
старого соединения попали в новое с той же четвёркой адресов/портов. Если
балансировщик открывает тысячи коротких соединений к бэкенду и сам их
закрывает, TIME_WAIT-сокеты занимают все эфемерные порты (~28 тысяч), и
новые `connect()` падают с `Cannot assign requested address`. Лечение —
keep-alive/пулы соединений к бэкенду, расширение
`ip_local_port_range`, `tcp_tw_reuse=1` для исходящих.

**2. `ping 8.8.8.8` работает, а `curl https://example.com` пишет "Could not
resolve host". Где искать?**
*Ответ:* IP-связность есть, сломан резолвинг имён. Проверить
`/etc/resolv.conf` (есть ли `nameserver`, не указывает ли он на
остановленный локальный stub `127.0.0.53`), `resolvectl status` для
реальных upstream-серверов, `getent hosts example.com` (путь приложения),
`dig @<nameserver> example.com` (сам DNS-сервер) и не режет ли файрвол
исходящий 53/UDP и 53/TCP.

**3. В `ip route` есть `default via 192.168.1.1 dev eth0` и `10.0.0.0/8 via
10.1.1.1 dev eth1`. Куда уйдёт пакет на 10.5.5.5, а куда на 1.1.1.1?**
*Ответ:* На 10.5.5.5 — через `10.1.1.1` в `eth1`: `/8` длиннее `/0`,
выигрывает самый длинный совпадающий префикс. На 1.1.1.1 — через
default-шлюз `192.168.1.1` в `eth0`. Проверить без гаданий:
`ip route get 10.5.5.5` (учтёт и policy routing через `ip rule`).

**4. Чем `ss` лучше `netstat`?**
*Ответ:* `ss` из iproute2 получает сокеты от ядра через netlink
(`sock_diag`) с фильтрацией на стороне ядра (`ss state time-wait dport
:443`), а `netstat` из устаревшего net-tools читает и разбирает текстовые
`/proc/net/tcp*` целиком. На хосте с сотнями тысяч соединений `netstat`
работает секунды и минуты, `ss` — доли секунды.

**5. `dig example.com` возвращает адрес, а приложение на том же хосте не может
резолвить имя. Почему так бывает?**
*Ответ:* `dig` ходит в DNS-сервер напрямую и игнорирует `/etc/nsswitch.conf`
и `/etc/hosts`; приложение резолвит через glibc `getaddrinfo()`, который
следует nsswitch (files, dns, myhostname, mdns, ...), применяет `search` и
`options ndots` из `resolv.conf` и может спрашивать AAAA раньше A. Нужно
проверять `getent hosts`/`getent ahosts` — он идёт тем же путём, что и
приложение. Также приложение может работать в другом network/mount
namespace (контейнер) со своим `resolv.conf`.

**6. Что такое veth-пара и как с её помощью контейнер получает сеть?**
*Ответ:* veth — два связанных виртуальных интерфейса: всё, что отправлено
в один, выходит из другого. Runtime создаёт пару, один конец перемещает в
network namespace контейнера (там он становится `eth0`), второй оставляет
на хосте и подключает к bridge (`docker0`, `cni0`). Дальше хост
маршрутизирует трафик (`ip_forward=1`) и делает NAT для выхода наружу.
Индекс пира виден в имени: `eth0@if87` в контейнере ↔ интерфейс с
индексом 87 на хосте.

**7. Как запустить tcpdump в сети контейнера, если в образе нет ни tcpdump, ни
shell?**
*Ответ:* Войти только в network namespace контейнера, оставшись в
файловой системе хоста: `sudo nsenter -t <PID> -n tcpdump -i eth0 -nn`,
где PID — процесс контейнера на хосте (`docker inspect -f
'{{.State.Pid}}'` или `crictl inspect`). Бинарник `tcpdump` берётся с хоста,
а интерфейсы и трафик — контейнера. Альтернатива в k8s — эфемерный
debug-контейнер (`kubectl debug`).

**8. Почему tcpdump без `-n` может исказить картину и даже нагрузить сеть?**
*Ответ:* По умолчанию tcpdump делает обратный DNS-резолв каждого IP и
преобразует номера портов в имена. Это порождает собственный DNS-трафик
(который попадает в захват, если вы слушаете порт 53), тормозит вывод и
при недоступном DNS выглядит как «tcpdump завис». `-nn` выключает резолв
и адресов, и портов.

**9. Почему `ip netns list` не показывает namespaces Docker-контейнеров?**
*Ответ:* `ip netns` видит только namespaces, привязанные bind-mount'ом в
`/run/netns/<имя>` (так их создаёт `ip netns add`). Docker и containerd
держат namespace живым через процесс контейнера и не создают такую
ссылку — namespace доступен как `/proc/<PID>/ns/net`. Чтобы увидеть его в
`ip netns`, можно сделать ссылку вручную:
`sudo ln -s /proc/<PID>/ns/net /run/netns/c1` — или просто
пользоваться `nsenter -t <PID> -n`.
