# Tier 1 — Docker Compose

Самый быстрый способ поднять стенд. Работает на любой ОС с Docker.
Используется в большинстве упражнений этой базы.

## Что нужно установить

- Docker Engine (Linux) или Docker Desktop / OrbStack (macOS/Windows)
- Compose v2 plugin (входит в Docker Engine 23+)

## Содержимое

- [01_theory/docker_compose_basics.md](01_theory/docker_compose_basics.md) —
  установка, структура compose файла, команды, паттерн стендов.
- [02_examples/](02_examples/) — типовые compose стенды (app+db, monitoring stack).
- [03_exercises/](03_exercises/) — упражнения на работу с compose.

## Проверка установки

```bash
docker compose version   # должен вернуть Docker Compose version v2.x
docker run --rm hello-world
```
