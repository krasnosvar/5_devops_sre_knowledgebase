# Сеть контейнеров — шпаргалка

Подробности и объяснения — в
[container_networking.md](./01_theory/container_networking.md).
⚠️ — опасная команда или частая ловушка.

## Docker bridge: что создаётся

| Шаг | Механизм | Как увидеть |
| :--- | :--- | :--- |
| Network namespace | изоляция стека | `ip netns` не покажет — смотреть через `nsenter` |
| veth pair | `eth0` в контейнере ↔ `vethXXXX` на хосте | `ip -br link show type veth` |
| Linux bridge | `docker0` / `br-<id>` | `ip -br link show type bridge`<br>`bridge link` |
| SNAT наружу | `MASQUERADE` в `POSTROUTING` | `sudo iptables -t nat -S POSTROUTING` |
| `-p 8080:80` | DNAT в цепочке `DOCKER` | `sudo iptables -t nat -S DOCKER` |

## Команды Docker

| Задача | Команда |
| :--- | :--- |
| Список сетей | `docker network ls` |
| Подсеть, шлюз, участники | `docker network inspect <net>` |
| Своя bridge-сеть (DNS по именам контейнеров) | `docker network create appnet` |
| Подключить работающий контейнер | `docker network connect appnet <c>` |
| IP контейнера | `docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' <c>` |
| Опубликованные порты | `docker port <c>` |
| Режимы сети | `--network bridge` (default) / `host` / `none` / `container:<c>` |
| Войти в netns контейнера с хоста | `sudo nsenter -t $(docker inspect -f '{{.State.Pid}}' <c>) -n ip a` |
| Отладочный контейнер в netns | `docker run --rm -it --network container:<c> nicolaka/netshoot` |
| Трафик на veth/bridge | `sudo tcpdump -ni docker0 port 80` |

## Kubernetes: модель и CNI

| Правило / факт | Значение |
| :--- | :--- |
| Pod ↔ Pod | без NAT, IP пода одинаков изнутри и снаружи |
| Бинарники CNI / конфиги | `/opt/cni/bin/` / `/etc/cni/net.d/` |
| Вызов CNI | containerd/CRI-O по запросу kubelet → плагин с командой `ADD` / `DEL`, IPAM выдаёт IP |
| NetworkPolicy | реализует CNI; Flannel их не поддерживает — политики молча не работают |

| Подход | Пример | Плюс | Минус |
| :--- | :--- | :--- | :--- |
| Overlay (VXLAN, UDP 4789) | Flannel, Cilium VXLAN | работает в любой L3-сети | инкапсуляция, меньше MTU (−50 байт) |
| Underlay (BGP) | Calico BGP (BIRD) | без инкапсуляции, максимум скорости | сеть должна знать маршруты подов |
| eBPF | Cilium | без iptables/kube-proxy, L7-политики | ядро посвежее, сложнее отладка |

## kube-proxy

| Режим | Поиск | Статус |
| :--- | :--- | :--- |
| `iptables` | линейные цепочки O(N), `statistic --mode random` | по умолчанию |
| `ipvs` | хэш-таблицы O(1) | deprecated с 1.35 |
| `nftables` | verdict maps, инкрементальные обновления | GA с 1.33 |
| Cilium kube-proxy replacement | eBPF-карты | вместо kube-proxy |

| Задача | Команда (на ноде) |
| :--- | :--- |
| Правила Service в iptables | `sudo iptables -t nat -S KUBE-SERVICES \| grep <clusterIP>` |
| Таблицы IPVS | `sudo ipvsadm -Ln` |
| Правила nftables-режима | `sudo nft list table ip kube-proxy` |
| ClusterIP не висит ни на одном интерфейсе | ищите его в правилах, не в `ip a` |

## DNS в поде

| Факт | Значение |
| :--- | :--- |
| Адрес CoreDNS (kubeadm) | `10.96.0.10` |
| `resolv.conf` пода | `search <ns>.svc.cluster.local svc.cluster.local cluster.local` + `options ndots:5` |
| Внешнее имя с < 5 точек | сначала перебор всех суффиксов `search` (NXDOMAIN), потом само имя |
| Обход | FQDN с точкой (`api.example.com.`) или `dnsConfig.options: ndots: "2"` |
| 5-секундные таймауты DNS | conntrack-гонка A/AAAA через SNAT → NodeLocal DNSCache (`169.254.20.10`) |

## Порты

| | `NodePort` | `hostPort` |
| :--- | :--- | :--- |
| Чья настройка | Service | контейнер в Pod |
| Где открыт | на всех нодах (30000–32767) | только на ноде с подом |
| Конфликт | нет | два пода с одним `hostPort` на ноде не встанут |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| Контейнер не выходит в интернет | `sysctl net.ipv4.ip_forward`, `iptables -t nat -S POSTROUTING` (MASQUERADE) |
| Контейнеры не резолвят друг друга по имени | сеть по умолчанию `bridge` — нет встроенного DNS, создайте свою |
| Порт не открывается снаружи | `docker port <c>`, цепочка `DOCKER` в `nat`, firewall хоста |
| Крупные пакеты теряются в overlay | MTU пода vs MTU ноды минус заголовок VXLAN |
| Пакеты к Service теряются, тысячи бэкендов | iptables-режим → nftables / Cilium |

> Проверка: `docker network`/`inspect`/`port`, `ip -br link`, `nsenter
> --help`, `tcpdump --help`, `iptables -S` синтаксис проверены локально
> (без изменения правил); не проверено: `ipvsadm`, `nft list table ip
> kube-proxy`, CNI-пути — нужна нода Kubernetes.
