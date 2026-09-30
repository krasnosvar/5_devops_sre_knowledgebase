# Раздел 2. Networking

Сети — фундамент, на котором держится всё остальное: без понимания TCP/IP,
DNS и балансировки нагрузки контейнеры и Kubernetes-сеть (CNI, kube-proxy,
Service) остаются "чёрной магией".

## Подразделы

0. [00_osi_and_tcpip](./00_osi_and_tcpip/) — OSI vs TCP/IP, инкапсуляция,
   TCP three-way handshake, TCP vs UDP, sockets, MTU и фрагментация.
   *Почему это важно:* база для диагностики любой сетевой проблемы —
   "на каком уровне сломалось".

1. [01_dns](./01_dns/) — дерево DNS, recursive vs authoritative, типы записей,
   TTL и кэширование, DNSSEC. *Почему это важно:* DNS — первая причина,
   которую проверяют при "сервис недоступен".

2. [02_http_and_tls](./02_http_and_tls/) — HTTP/1.1 keep-alive и Head-of-Line
   Blocking, HTTP/2 мультиплексирование, HTTP/3/QUIC, TLS handshake,
   сертификаты и цепочка доверия, кэширование (ETag/Cache-Control).

3. [03_load_balancing](./03_load_balancing/) — L4 vs L7, алгоритмы
   (round robin/least conn/consistent hashing), health checks (активные/
   пассивные), sticky sessions, reverse proxy vs load balancer.

4. [04_bgp_and_routing](./04_bgp_and_routing/) — таблица маршрутизации ядра,
   статическая vs динамическая маршрутизация, BGP (AS Path, почему не
   самый быстрый маршрут побеждает), BGP hijacking/RPKI, BGP в k8s (MetalLB).
   *Без формальных упражнений* — полноценная лаба требует выделенных
   роутеров; в примерах — рабочий FRRouting peering для эксперимента.

5. [05_iptables_and_nftables](./05_iptables_and_nftables/) — netfilter,
   таблицы/цепочки iptables, порядок обработки пакета (INPUT vs FORWARD),
   DNAT/SNAT/MASQUERADE, conntrack, nftables и почему это архитектурная
   замена, а не косметика.

6. [06_vpc_and_cloud_networking](./06_vpc_and_cloud_networking/) — VPC,
   public/private subnets, Internet Gateway/NAT Gateway/Route Tables,
   Security Group vs Network ACL (stateful vs stateless, Allow-only vs
   Allow+Deny), VPC Peering vs Transit Gateway.

## Как проходить

00 → 01 → 02 строго по порядку (фундамент: транспорт → имена → приложение).
03 и 05 — параллельно, обе опираются на 00. 04 — по желанию (концептуально
важно, но лабать тяжело). 06 — когда дойдёте до реального облака (см.
[`../7_compute_platforms/`](../7_compute_platforms/)).

## Упражнения — тиры

🐳 Tier 1: 00, 01, 02, 03, 05 — всё на Docker Compose / контейнерах с `NET_ADMIN`
☁️ Tier 3: 06 — требует реальный AWS-аккаунт (free tier); не забывайте `terraform destroy`
Без формальной лабы: 04 (BGP) — только теория + рабочий пример FRRouting peering
