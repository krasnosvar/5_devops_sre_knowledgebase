# 03. Балансировка нагрузки

## Зачем

Любой сервис с более чем одной репликой стоит за балансировщиком. Выбор
L4 или L7, алгоритма и health checks определяет, переживёт ли система падение
backend'а или сама устроит каскадный отказ.

## Пререквизиты

- [00_osi_and_tcpip](../00_osi_and_tcpip/) — L4 (TCP) vs L7 (HTTP).
- [02_http_and_tls](../02_http_and_tls/) — HTTP и nginx как reverse proxy.

> **Забегание вперёд.** Здесь используется Docker, который подробно
> разбирается в [3_containers](../../3_containers/). Для этой темы
> достаточно: `docker run`/`docker exec`/`docker rm -f` и
> `docker compose up -d`/`down`. Если Docker ещё не освоен — лабу можно
> пропустить и вернуться к ней позже: теория читается без неё.

## Файлы

- [01_theory/load_balancing.md](./01_theory/load_balancing.md) — L4 vs L7,
  алгоритмы, health checks, sticky sessions.
- [02_examples/](./02_examples/) — `docker-compose.yml`, `nginx-lb.conf`
  (балансировщик), `nginx.conf` (backend'ы).
- [03_exercises/README.md](./03_exercises/README.md) — 5 упражнений
  (🐳 Tier 1).
- [04_exercises_answers/](./04_exercises_answers/) — ответы
  (`load_balancing_answers.md`).

## Как проходить

1. Прочитать теорию.
2. Запустить примеры из `02_examples/` и сверить поведение с теорией.
3. Решить упражнения, не подглядывая в ответы.
4. Сверить с `04_exercises_answers/`.

## Когда двигаться дальше

- Можете объяснить разницу round robin, least_conn и consistent hashing.
- Можете объяснить, как health check, зависящий от БД, приводит к
  каскадному отказу.
- Можете назвать альтернативу sticky sessions для stateful-логики.

Дальше: [04_bgp_and_routing](../04_bgp_and_routing/).
