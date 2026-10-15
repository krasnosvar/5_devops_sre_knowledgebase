# 01. Tier 1 — Docker Compose

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — быстрый
> справочник команд, флагов и типовых конфигов.

## Зачем

Самый быстрый способ поднять стенд: одна команда поднимает приложение,
базу, кэш и мониторинг, другая — удаляет всё без следа. Работает на любой
ОС с Docker и используется в большинстве упражнений этой базы.

## Пререквизиты

- Базовая работа в shell — [1_linux_and_shell](../../1_linux_and_shell/).

> **Забегание вперёд.** Здесь используется Docker, который подробно
> разбирается в [3_containers](../../3_containers/). Для этой темы
> достаточно: образ vs контейнер, `docker run`, `docker ps`,
> `docker logs`, `docker exec`. Устройство образов, сетей и volumes — там.

## Что нужно установить

- Docker Engine (Linux) или Docker Desktop / OrbStack (macOS/Windows)
- Compose v2 plugin (входит в Docker Engine 23+)

## Файлы

- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: команды, флаги, типовой
  compose-файл.
- [01_theory/docker_compose_basics.md](01_theory/docker_compose_basics.md) —
  установка, структура compose файла, команды, паттерн стендов.
- [02_examples/full-stack.yaml](02_examples/full-stack.yaml) — стенд
  nginx → Flask app → PostgreSQL + Redis; рядом
  [nginx.conf](02_examples/nginx.conf) и [app/app.py](02_examples/app/app.py).
- [03_exercises/README.md](03_exercises/README.md) — 4 упражнения, 🐳 Tier 1.
- [04_exercises_answers/compose-answers.md](04_exercises_answers/compose-answers.md) —
  ответы; файлы решений в [02_override/](04_exercises_answers/02_override/)
  и [03_profiles/](04_exercises_answers/03_profiles/).

## Как проходить

1. Установить Docker и проверить установку (ниже).
2. Прочитать теорию.
3. Поднять `full-stack.yaml`, открыть `http://localhost/`, удалить стенд.
4. Сделать упражнения, затем сверить с ответами.

## Проверка установки

```bash
docker compose version   # должен вернуть Docker Compose version v2.x
docker run --rm hello-world
```

## Когда двигаться дальше

- Можете объяснить, чем `depends_on` с `condition: service_healthy`
  отличается от простого `depends_on`.
- Можете без подсказки собрать dev/prod конфиг через override-файлы и
  посмотреть итог в `docker compose config`.
- Знаете разницу между `down` и `down -v`.
- Дальше — [02_local_vms](../02_local_vms/).
