# OSI и TCP/IP — шпаргалка

Подробности и объяснения — в
[osi_and_tcpip.md](./01_theory/osi_and_tcpip.md). ⚠️ — опасная команда или
частая ловушка.

## Уровни и диагностика снизу вверх

| OSI | TCP/IP | Протоколы | Чем проверить |
| :--- | :--- | :--- | :--- |
| L1–L2 | Link | Ethernet, ARP | `ip -br link`, `ip neigh` |
| L3 | Internet | IP, ICMP | `ip route get <ip>`, `ping -c3 <ip>`, `tracepath <ip>` |
| L4 | Transport | TCP, UDP | `ss -tlnp`, `nc -zv <host> <port>` |
| L5–L7 | Application | HTTP, DNS, TLS, gRPC | `curl -v`, `dig`, `openssl s_client` |

| Симптом | Уровень | Куда смотреть |
| :--- | :--- | :--- |
| `NO-CARRIER`, интерфейс `DOWN` | L1–L2 | `ip -br link`, кабель/линк, `ethtool <if>` |
| `Network is unreachable` | L3 | `ip route` — нет маршрута / default |
| `No route to host` | L3 | ARP не отвечает (`ip neigh`) или ICMP reject файрвола |
| `Connection refused` (RST) | L4 | порт не слушается: `ss -tlnp` на сервере |
| Таймаут на connect, `SYN-SENT` висит | L3/L4 | SYN дропается: файрвол, SG, маршрут |
| `Could not resolve host` | L7 | DNS: `dig <name>`, `/etc/resolv.conf` |
| Маленькие запросы ок, большие виснут | L3 | MTU / PMTU black hole (ниже) |

## TCP handshake и состояния

| Задача | Команда |
| :--- | :--- |
| Слушающие TCP-сокеты + процесс | `ss -tlnp` |
| Слушающие UDP | `ss -ulnp` |
| Активные соединения + процесс | `ss -tnp state established` |
| Застрявшие на SYN (клиент) | `ss -tan state syn-sent` |
| Полуоткрытые на сервере (SYN flood?) | `ss -tan state syn-recv` |
| Сводка по состояниям | `ss -s` |
| Соединения к порту | `ss -tn 'dport = :443'` |
| Таймеры/RTT/cwnd сокета | `ss -tni` |
| Поймать handshake | `tcpdump -i any -n 'tcp[tcpflags] & (tcp-syn\|tcp-ack) != 0' -c 6` |
| Только SYN без ACK | `tcpdump -i any -n 'tcp[tcpflags] == tcp-syn'` |
| Трафик к хосту/порту в файл ⚠️ | `tcpdump -i eth0 -n host 10.0.0.5 and port 443 -w cap.pcap` |
| Прочитать pcap | `tcpdump -n -r cap.pcap` |

| Состояние | Что значит |
| :--- | :--- |
| `SYN-SENT` | клиент отправил SYN, ответа нет — файрвол/маршрут |
| `SYN-RECV` | сервер ответил SYN-ACK, ждёт ACK — много = SYN flood |
| `ESTABLISHED` | соединение рабочее — проблема уже в приложении |
| `TIME-WAIT` | закрыл инициатор, ждёт 2×MSL (60 с в Linux) |
| `CLOSE-WAIT` | удалённая сторона закрыла, приложение не вызвало `close()` — утечка |

## TCP vs UDP

| | TCP | UDP |
| :--- | :--- | :--- |
| Соединение | handshake (+1 RTT) | нет |
| Доставка / порядок | гарантированы (retransmit, seq) | нет |
| Congestion control | есть | нет |
| Заголовок | 20+ байт | 8 байт |
| Типично | HTTP/1.1, HTTP/2, БД, SSH | DNS, VoIP, видео, игры, QUIC (HTTP/3) |

## Сокеты, порты, sysctl

| Параметр | Значение / команда |
| :--- | :--- |
| Идентификатор соединения | 5-tuple: протокол, src IP, src port, dst IP, dst port |
| Эфемерные порты | `sysctl net.ipv4.ip_local_port_range` (по умолчанию `32768 60999` ≈ 28 тыс.) |
| SYN cookies | `sysctl net.ipv4.tcp_syncookies` (`1` — включены при переполнении) |
| Очередь SYN | `sysctl net.ipv4.tcp_max_syn_backlog` |
| Очередь accept | `sysctl net.core.somaxconn` (4096 с ядра 5.4; реально `min(backlog, somaxconn)`) |
| Keepalive (по умолчанию выкл. в сокете) | `net.ipv4.tcp_keepalive_time` = 7200 с; включается `SO_KEEPALIVE` |

## MTU и фрагментация

| Задача | Команда / значение |
| :--- | :--- |
| MTU интерфейса | `ip link show eth0` (поле `mtu`) |
| Проверить путь без фрагментации | `ping -M do -s 1472 <ip>` (1472 + 28 = 1500) |
| PMTU до хоста | `tracepath <ip>` |
| Поменять MTU ⚠️ (рвёт связь при ошибке) | `ip link set dev eth0 mtu 1450` |
| Ethernet / jumbo | 1500 / 9000 |
| Оверхед VXLAN | 50 байт → внутренний MTU 1450 |

- ⚠️ PMTU black hole: где-то режут ICMP `Fragmentation Needed` — handshake
  проходит, большие ответы висят. Лечится разрешением ICMP или MSS clamping.
- ⚠️ Jumbo frames дают выигрыш только если MTU согласован end-to-end.
- ⚠️ Port exhaustion: тысячи коротких исходящих соединений на один
  `dst:port` — нужен keep-alive/пул, а не новый connect на запрос.

> Проверка: фильтры `tcpdump -d` (4.99.6), `ss`-фильтры и дефолты sysctl —
> на Linux 7.2; не проверено: —.
