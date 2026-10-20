# 06. Паттерны Docker Compose

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — быстрый
> справочник команд, флагов и типовых конфигов.

## Зачем

Compose — основной инструмент локальной разработки и Tier-1 лаб этой
базы. Тема показывает, как сделать стенд воспроизводимым: healthchecks и
`depends_on` с условием, профили, override-файлы, переменные окружения,
лимиты ресурсов.

## Пререквизиты

- [03_networking](../03_networking/) и [04_storage](../04_storage/) —
  сети и volumes, которые compose создаёт за вас.

## Файлы

- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: healthcheck, `.env`, override,
  профили.
- [01_theory/compose_patterns.md](./01_theory/compose_patterns.md) —
  depends_on и healthcheck, `.env` vs `env_file`, override и profiles, сети
  и volumes.
- [02_examples/](./02_examples/) — `production-stack.yaml` (app + db +
  cache + nginx), `.env.example`, `db/init.sql`, `nginx/nginx.conf`.
- [03_exercises/README.md](./03_exercises/README.md) — 4 упражнения
  (🐳 Tier 1).
- [04_exercises_answers/](./04_exercises_answers/) — ответы
  (`compose_answers.md`, `docker-compose.answer.yml`).

## Как проходить

1. Прочитать теорию.
2. Запустить примеры из `02_examples/` и сверить поведение с теорией.
3. Решить упражнения, не подглядывая в ответы.
4. Сверить с `04_exercises_answers/`.

## Когда двигаться дальше

- Можете объяснить разницу `depends_on` с `service_started` и
  `service_healthy`.
- Можете сделать backup и restore named volume без потери данных.
- Можете включать опциональные сервисы через profiles.

Дальше: [07_dockerfile_best_practices](../07_dockerfile_best_practices/).
