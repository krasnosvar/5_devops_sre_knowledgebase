# 00. OSI и TCP/IP

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — команды и шаблоны одним экраном.

## Зачем

Любая сетевая диагностика начинается с вопроса «на каком уровне
сломалось»: DNS, TCP-соединение, TLS или приложение. Тема даёт модель уровней,
TCP handshake, разницу TCP/UDP, сокеты и MTU — то, без чего не прочитать
вывод `tcpdump`/`ss` и не понять, почему «пинг есть, а сервис недоступен».

## Пререквизиты

- [1_linux_and_shell/06_networking_basics](../../1_linux_and_shell/06_networking_basics/)
  — `ip`, `ss`, network namespaces: инструменты, которыми здесь смотрим на
  сокеты и интерфейсы.

> **Забегание вперёд.** Здесь используется Docker, который подробно
> разбирается в [3_containers](../../3_containers/). Для этой темы
> достаточно: `docker run`/`docker exec`/`docker rm -f` и
> `docker compose up -d`/`down`. Если Docker ещё не освоен — лабу можно
> пропустить и вернуться к ней позже: теория читается без неё.

## Файлы

- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: ss, tcpdump, MTU, состояния TCP.
- [01_theory/osi_and_tcpip.md](./01_theory/osi_and_tcpip.md) — OSI vs
  TCP/IP, инкапсуляция, handshake, TCP vs UDP, sockets, MTU и фрагментация.
- [02_examples/](./02_examples/) — `tcpdump_and_ss.sh`: слушающие сокеты,
  состояния соединений, MTU интерфейсов.
- [03_exercises/README.md](./03_exercises/README.md) — 3 упражнения
  (🐳 Tier 1: два контейнера netshoot).
- [04_exercises_answers/](./04_exercises_answers/) — ответы
  (`tcp_udp_demo.md`).

## Как проходить

1. Прочитать теорию.
2. Запустить примеры из `02_examples/` и сверить поведение с теорией.
3. Решить упражнения, не подглядывая в ответы.
4. Сверить с `04_exercises_answers/`.

## Когда двигаться дальше

- Можете по выводу `tcpdump` показать SYN, SYN-ACK, ACK и закрытие
  соединения.
- Можете объяснить, почему TCP переживает потерю пакетов, а UDP — нет.
- Можете без подсказки назвать причину `Cannot assign requested address`
  и роль `TIME-WAIT`.

Дальше: [01_dns](../01_dns/).
