# Маршрутизация и BGP — шпаргалка

Подробности и объяснения — в
[bgp_and_routing.md](./01_theory/bgp_and_routing.md). ⚠️ — опасная команда
или частая ловушка.

## ip route (Linux)

| Задача | Команда |
| :--- | :--- |
| Таблица маршрутизации | `ip route show` (кратко `ip r`) |
| Какой маршрут выберет ядро | `ip route get 8.8.8.8` |
| С учётом источника / входного if | `ip route get 8.8.8.8 from 10.0.0.5 iif eth1` |
| Добавить статический маршрут ⚠️ | `ip route add 192.168.50.0/24 via 10.0.0.254 dev eth1` |
| Заменить (или создать) | `ip route replace 192.168.50.0/24 via 10.0.0.253` |
| Удалить ⚠️ | `ip route del 192.168.50.0/24` |
| Default gateway ⚠️ (по SSH — можно потерять доступ) | `ip route replace default via 192.168.1.1` |
| «Чёрная дыра» для префикса | `ip route add blackhole 203.0.113.0/24` |
| Policy routing: правила и таблицы | `ip rule show`, `ip route show table <id>` |
| Включён ли форвардинг (роутер) | `sysctl net.ipv4.ip_forward` |
| Трассировка пути | `tracepath <ip>` / `traceroute -n <ip>` / `mtr -n <ip>` |
| ARP/neighbor-таблица | `ip neigh` |

| Правило выбора | Смысл |
| :--- | :--- |
| Longest prefix match | `/24` побеждает `/16` и `default` (`/0`) независимо от порядка |
| При равном префиксе | меньший `metric` |
| `default` | только если не подошёл ни один более узкий маршрут |
| ⚠️ `ip route add` | не переживает ребут — сохранять в netplan/NetworkManager/systemd-networkd |

## Статика vs динамика

| | Статическая | Динамическая |
| :--- | :--- | :--- |
| Как | `ip route add` руками / IaC | OSPF (внутри организации), BGP (между AS и в ДЦ) |
| Отказ линка | трафик теряется до ручной правки | пересчёт за секунды |
| Когда | маленькая сеть, один выход | несколько путей, ДЦ, k8s с MetalLB/Cilium BGP |

## BGP: выбор маршрута (упрощённо, по порядку)

| # | Атрибут | Лучше |
| :--- | :--- | :--- |
| 1 | Weight (Cisco/FRR, локально) | больше |
| 2 | `LOCAL_PREF` (внутри AS) | больше |
| 3 | Locally originated | свой маршрут |
| 4 | `AS_PATH` | короче |
| 5 | `ORIGIN` | IGP < EGP < incomplete |
| 6 | `MED` | меньше |
| 7 | eBGP vs iBGP | eBGP |
| 8 | IGP metric до next-hop | меньше |
| 9 | Router ID | меньше |

⚠️ Задержку и полосу BGP не измеряет: «короче по AS» ≠ «быстрее».

## FRR (vtysh)

| Задача | Команда |
| :--- | :--- |
| Войти в CLI | `vtysh` (в лабе: `docker compose exec router1 vtysh`) |
| Сессии и число префиксов | `vtysh -c 'show bgp summary'` |
| BGP-таблица | `vtysh -c 'show ip bgp'` |
| Маршруты в RIB/ядре | `vtysh -c 'show ip route'` / `ip route` |
| Детали соседа | `vtysh -c 'show ip bgp neighbors 10.100.0.12'` |
| Что отдаём / получили (после политики) | `show ip bgp neighbors <ip> advertised-routes` / `routes` |
| Текущий конфиг | `vtysh -c 'show running-config'` |
| Мягкий перезапрос анонсов | `vtysh -c 'clear ip bgp <ip> soft'` |

```text
router bgp 64500
 bgp router-id 10.100.0.11
 neighbor 10.100.0.12 remote-as 64501
 address-family ipv4 unicast
  neighbor 10.100.0.12 route-map PERMIT-ALL in
  neighbor 10.100.0.12 route-map PERMIT-ALL out
  network 203.0.113.0/24
 exit-address-family
!
route-map PERMIT-ALL permit 10
```

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| Сессия `Established`, префиксов 0, `(Policy)` в summary | RFC 8212: eBGP без политики режется — нужен `route-map` in/out (или `no bgp ebgp-requires-policy` в лабе) |
| `network X/24` не анонсируется | префикса нет в RIB: `bgp network import-check` — добавить маршрут/`blackhole` |
| Сессия в `Active`/`Connect` | TCP/179 недоступен, неверный `remote-as` или адрес соседа |
| Трафик идёт «через другой континент» | политика `LOCAL_PREF`, peering-договорённости, не задержка |
| Чужой префикс анонсируется | hijack/утечка: RPKI ROA, фильтры префиксов |
| Транзит через Linux не идёт | `net.ipv4.ip_forward=0`, `FORWARD` в файрволе, rp_filter |

## BGP в Kubernetes

| Где | Зачем |
| :--- | :--- |
| MetalLB BGP mode | анонс VIP `LoadBalancer` роутерам ДЦ, ECMP на несколько нод |
| MetalLB L2 (ARP) mode | VIP висит на одной ноде — упор в её линк |
| Cilium BGP | анонс Pod CIDR / Service IP наружу без NAT |

> Проверка: `ip route`/`ip rule` выполнены в одноразовом netns
> (`unshare -rn`); конфиг-сниппет и команды `vtysh` — в контейнере
> `quay.io/frrouting/frr:10.2.1`; не проверено: —.
