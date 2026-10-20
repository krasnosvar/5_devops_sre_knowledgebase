# 01. DNS

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — команды и шаблоны одним экраном.

## Зачем

DNS — первое, что проверяют при «сервис недоступен»: неверная запись,
устаревший кэш или долгий TTL ломают выкатку не хуже упавшего сервера. Тема
разбирает дерево DNS, recursive vs authoritative, типы записей, TTL и
кэширование — на своём authoritative-сервере CoreDNS.

## Пререквизиты

- [00_osi_and_tcpip](../00_osi_and_tcpip/) — UDP/TCP и порты: DNS
  работает поверх них.

> **Забегание вперёд.** Здесь используется Docker, который подробно
> разбирается в [3_containers](../../3_containers/). Для этой темы
> достаточно: `docker run`/`docker exec`/`docker rm -f` и
> `docker compose up -d`/`down`. Если Docker ещё не освоен — лабу можно
> пропустить и вернуться к ней позже: теория читается без неё.

## Файлы

- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: dig, типы записей, TTL-миграция.
- [01_theory/dns.md](./01_theory/dns.md) — иерархия DNS, резолвинг,
  типы записей, TTL, DNSSEC.
- [02_examples/](./02_examples/) — `docker-compose.yml` с CoreDNS,
  `Corefile`, зона `zones/example.com.db`.
- [03_exercises/README.md](./03_exercises/README.md) — 4 упражнения
  (🐳 Tier 1).
- [04_exercises_answers/](./04_exercises_answers/) — ответы
  (`dns_answers.md`).

## Как проходить

1. Прочитать теорию.
2. Запустить примеры из `02_examples/` и сверить поведение с теорией.
3. Решить упражнения, не подглядывая в ответы.
4. Сверить с `04_exercises_answers/`.

## Когда двигаться дальше

- Можете объяснить разницу recursive и authoritative сервера и путь
  запроса от корня.
- Можете с помощью `dig` найти TTL, CNAME-цепочку и TXT-запись.
- Можете объяснить, почему смена записи «видна» не сразу.

Дальше: [02_http_and_tls](../02_http_and_tls/).
