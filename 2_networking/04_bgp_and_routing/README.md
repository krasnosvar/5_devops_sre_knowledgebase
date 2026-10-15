# 04. BGP и маршрутизация

## Зачем

Таблица маршрутизации ядра решает, куда уйдёт каждый пакет, а BGP —
как связаны сети провайдеров и как MetalLB/Calico анонсируют адреса в
Kubernetes. Понимание BGP объясняет глобальные инциденты («маршрут
утёк — пол-интернета недоступно») и bare-metal балансировку.

## Пререквизиты

- [00_osi_and_tcpip](../00_osi_and_tcpip/) — IP-адресация и подсети.
- [1_linux_and_shell/06_networking_basics](../../1_linux_and_shell/06_networking_basics/)
  — `ip route`.

> **Забегание вперёд.** Здесь используется Docker, который подробно
> разбирается в [3_containers](../../3_containers/). Для этой темы
> достаточно: `docker run`/`docker exec`/`docker rm -f` и
> `docker compose up -d`/`down`. Если Docker ещё не освоен — лабу можно
> пропустить и вернуться к ней позже: теория читается без неё.

## Файлы

- [01_theory/bgp_and_routing.md](./01_theory/bgp_and_routing.md) —
  маршрутизация ядра, статика vs динамика, BGP, hijacking/RPKI, BGP в k8s.
- [02_examples/](./02_examples/) — `README.md` и `docker-compose.yml` с двумя
  роутерами FRRouting (`router1/`, `router2/`): рабочий BGP peering.
- Без формальных упражнений: полноценная лаба требует выделенных роутеров;
  пример FRR достаточен для экспериментов.

## Как проходить

1. Прочитать теорию.
2. Поднять пример FRRouting по [02_examples/README.md](./02_examples/README.md)
   и посмотреть BGP-таблицы и AS Path.
3. Поменять анонсы/фильтры в `frr.conf` и наблюдать, как меняется таблица.

## Когда двигаться дальше

- Можете объяснить, по какому правилу ядро выбирает маршрут
  (longest prefix match).
- Можете объяснить, почему BGP выбирает не самый быстрый путь.
- Можете поднять пример FRR и показать в выводе AS Path и next-hop.

Дальше: [05_iptables_and_nftables](../05_iptables_and_nftables/).
