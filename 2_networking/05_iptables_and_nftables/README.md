# 05. iptables и nftables

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — команды и шаблоны одним экраном.

## Зачем

netfilter — это и файрвол сервера, и NAT в Docker, и kube-proxy в
Kubernetes. Без понимания цепочек, DNAT/SNAT и conntrack не разобраться,
почему порт «открыт, но не отвечает» или куда пропал трафик контейнера.

## Пререквизиты

- [00_osi_and_tcpip](../00_osi_and_tcpip/) — заголовки IP/TCP, по которым
  матчатся правила.
- [1_linux_and_shell/06_networking_basics](../../1_linux_and_shell/06_networking_basics/)
  — интерфейсы и маршруты Linux.

> **Забегание вперёд.** Здесь используется Docker, который подробно
> разбирается в [3_containers](../../3_containers/). Для этой темы
> достаточно: `docker run`/`docker exec`/`docker rm -f` и
> `docker compose up -d`/`down`. Если Docker ещё не освоен — лабу можно
> пропустить и вернуться к ней позже: теория читается без неё.

## Файлы

- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: iptables, nft, NAT, conntrack.
- [01_theory/iptables_and_nftables.md](./01_theory/iptables_and_nftables.md)
  — netfilter, таблицы и цепочки, путь пакета, NAT, conntrack, nftables.
- [02_examples/](./02_examples/) — `basic_rules.sh` (default-deny),
  `dnat_snat_demo.sh` (проброс порта и SNAT).
- [03_exercises/README.md](./03_exercises/README.md) — 5 упражнений
  (🐳 Tier 1: контейнер с `NET_ADMIN`).
- [04_exercises_answers/](./04_exercises_answers/) — ответы
  (`iptables_nftables_answers.md`).

## Как проходить

1. Прочитать теорию.
2. Запустить примеры из `02_examples/` и сверить поведение с теорией.
3. Решить упражнения, не подглядывая в ответы.
4. Сверить с `04_exercises_answers/`.

## Когда двигаться дальше

- Можете объяснить, когда пакет идёт через INPUT, а когда через FORWARD.
- Можете без подсказки написать DNAT-проброс порта.
- Можете показать, что правила `iptables` на современной системе — это
  nftables.

Дальше: [06_vpc_and_cloud_networking](../06_vpc_and_cloud_networking/).
