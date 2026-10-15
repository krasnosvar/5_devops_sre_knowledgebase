# 03. Сеть контейнеров

## Зачем

Контейнер «не видит» базу, порт опубликован, но не отвечает, имя
сервиса не резолвится — ежедневные проблемы. Тема показывает, что стоит за
сетевыми режимами Docker: veth-пары, bridge, iptables NAT и встроенный DNS.

## Пререквизиты

- [2_networking/05_iptables_and_nftables](../../2_networking/05_iptables_and_nftables/)
  — NAT и цепочки netfilter, которыми Docker публикует порты.
- [1_linux_and_shell/06_networking_basics](../../1_linux_and_shell/06_networking_basics/) —
  network namespaces, `ip link`, veth.

> **Забегание вперёд.** Разделы 2-6 теории описывают сеть Kubernetes,
> которая подробно разбирается в
> [4_kubernetes/03_networking](../../4_kubernetes/03_networking/). Для этой
> темы достаточно знать, что под — это группа контейнеров с общим network
> namespace, а Service — стабильный адрес перед подами. Если Kubernetes ещё
> не освоен — эти разделы можно пропустить и вернуться к ним позже.

## Файлы

- [01_theory/container_networking.md](./01_theory/container_networking.md)
  — veth, bridge и NAT в Docker; CNI, overlay vs underlay, kube-proxy
  (iptables/IPVS), Cilium, CoreDNS и `ndots`.
- [02_examples/](./02_examples/) — `network_demo.yaml` (изолированные сети
  frontend/backend, `internal: true`) и `frontend.conf` (nginx-прокси).
- Без отдельных упражнений: пример сам является лабой — команды проверки
  связности в конце `network_demo.yaml`.

## Как проходить

1. Прочитать теорию.
2. Поднять `docker compose -f network_demo.yaml up -d` и выполнить проверки
   из комментариев в конце файла.
3. Найти veth-пары и правила NAT на хосте (`ip link`, `iptables -t nat -S`
   или `nft list ruleset`), `docker compose -f network_demo.yaml down`.

## Когда двигаться дальше

- Можете объяснить путь пакета из контейнера в интернет в режиме bridge.
- Можете объяснить, почему контейнеры в разных сетях не резолвят имена
  друг друга.
- Можете объяснить, чем `-p 8080:80` реализован на хосте.

Дальше: [04_storage](../04_storage/).
