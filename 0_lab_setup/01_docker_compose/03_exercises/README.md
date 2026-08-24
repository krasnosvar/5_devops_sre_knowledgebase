# Упражнения — Docker Compose

## 01 — Поднять стек app + db + healthcheck

**Задача:** Написать docker-compose.yml который поднимает:
- PostgreSQL с healthcheck
- Простое Python/Go приложение которое подключается к БД
- nginx как reverse proxy
- app запускается только когда db healthy

```yaml
# TODO: заполнить docker-compose.yml
services:
  db:
    image: postgres:16-alpine
    healthcheck:
      test: ???
      interval: 5s
      retries: 10

  app:
    depends_on:
      db:
        condition: ???   # ждать healthy
```

```bash
docker compose up -d
docker compose ps       # убедиться что все healthy
docker compose logs db  # посмотреть логи postgres
```

## 02 — Override файлы для dev и prod

**Задача:** Создать три файла:
- `docker-compose.yml` — базовый (без портов, без volumes bind)
- `docker-compose.override.yml` — dev: локальный build, bind mount кода, debug порты
- `docker-compose.prod.yml` — prod: ready image, resource limits, restart policy

```bash
# dev (автоматически подхватывает override.yml)
docker compose up -d

# prod
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# посмотреть итоговый конфиг
docker compose config
docker compose -f docker-compose.yml -f docker-compose.prod.yml config
```

## 03 — Profiles

**Задача:** Добавить profile `monitoring` который поднимает Prometheus + Grafana
только когда явно указан.

```bash
docker compose up -d                         # только основные сервисы
docker compose --profile monitoring up -d   # + Prometheus + Grafana
```

## 04 — Очистка и инспекция

```bash
# Сколько места занимают Docker данные?
docker system df

# Посмотреть все именованные volumes
docker volume ls

# Удалить стенд полностью
docker compose down -v

# Удалить все неиспользуемые данные (осторожно!)
docker system prune -a --volumes
```
