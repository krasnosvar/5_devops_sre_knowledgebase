# 02. HTTP и TLS

## Зачем

Почти весь трафик сервисов — HTTP поверх TLS. Ошибки сертификатов,
неправильное кэширование, сюрпризы с заголовками в nginx и разница
HTTP/1.1/2/3 — ежедневные причины инцидентов и вопросов на собеседовании.

## Пререквизиты

- [00_osi_and_tcpip](../00_osi_and_tcpip/) — TCP-соединение, поверх
  которого строятся HTTP и TLS.
- [01_dns](../01_dns/) — как клиент находит адрес сервера.

> **Забегание вперёд.** Здесь используется Docker, который подробно
> разбирается в [3_containers](../../3_containers/). Для этой темы
> достаточно: `docker run`/`docker exec`/`docker rm -f` и
> `docker compose up -d`/`down`. Если Docker ещё не освоен — лабу можно
> пропустить и вернуться к ней позже: теория читается без неё.

## Файлы

- [01_theory/http_and_tls.md](./01_theory/http_and_tls.md) — HTTP/1.1,
  HTTP/2, HTTP/3/QUIC, TLS handshake, цепочка доверия, кэширование.
- [02_examples/](./02_examples/) — `docker-compose.yml` + `nginx.conf` с TLS,
  `gen-cert.sh` (самоподписанный сертификат), `html/index.html`.
- [03_exercises/README.md](./03_exercises/README.md) — 4 упражнения
  (🐳 Tier 1).
- [04_exercises_answers/](./04_exercises_answers/) — ответы
  (`http_tls_answers.md`).

## Как проходить

1. Прочитать теорию.
2. Запустить примеры из `02_examples/` и сверить поведение с теорией.
3. Решить упражнения, не подглядывая в ответы.
4. Сверить с `04_exercises_answers/`.

## Когда двигаться дальше

- Можете по выводу `curl -v` определить версию HTTP и TLS.
- Можете объяснить, когда сервер вернёт 304 и как работает ETag.
- Можете объяснить ловушку наследования `add_header` в nginx.

Дальше: [03_load_balancing](../03_load_balancing/).
