# Упражнения — Docker Compose Patterns

## 01 — Healthcheck + depends_on

**Задача:** Исправить docker-compose.yml чтобы app не стартовал раньше чем db готов.

```yaml
# bad-compose.yml (app падает потому что db ещё не готов)
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: test

  app:
    image: python:3.12-slim
    command: python -c "import psycopg2; conn = psycopg2.connect('postgresql://postgres:test@db/postgres'); print('Connected!')"
    depends_on:
      - db    # просто ждёт старта контейнера, не готовности
```

```bash
docker compose -f bad-compose.yml up   # app упадёт

# TODO: добавить healthcheck к db и condition: service_healthy к app
# Файл: good-compose.yml

docker compose -f good-compose.yml up  # должно работать
```

## 02 — Именованные volumes и backup

```bash
# Поднять postgres
docker compose up -d db

# Записать данные
docker compose exec db psql -U postgres -c "CREATE TABLE test (id serial, val text);"
docker compose exec db psql -U postgres -c "INSERT INTO test(val) VALUES ('hello from exercise 02');"

# Backup volume в tar архив
docker run --rm \
  -v postgres_data:/source:ro \
  -v $(pwd):/backup \
  alpine tar czf /backup/pg-backup.tar.gz -C /source .

# Удалить всё включая volume
docker compose down -v

# Восстановить данные из бэкапа
docker compose up -d db
docker run --rm \
  -v postgres_data:/target \
  -v $(pwd):/backup:ro \
  alpine tar xzf /backup/pg-backup.tar.gz -C /target

# Перезапустить и проверить данные
docker compose restart db
docker compose exec db psql -U postgres -c "SELECT * FROM test;"
```

## 03 — Profiles: опциональные сервисы

**Задача:** Добавить профили `debug` и `monitoring` к существующему стеку.

```yaml
services:
  app:
    image: nginx:alpine
    ports: ["8080:80"]

  # Только при --profile debug
  adminer:
    image: adminer
    profiles: [debug]
    ports: ["8081:8080"]

  # Только при --profile monitoring
  prometheus:
    image: prom/prometheus
    profiles: [monitoring]
    ports: ["9090:9090"]
```

```bash
docker compose up -d                         # только app
docker compose --profile debug up -d        # app + adminer
docker compose --profile debug --profile monitoring up -d  # всё
docker compose ps   # посмотреть что запущено
```

## 04 — Resource limits в compose

**Задача:** Добавить memory и CPU limits ко всем сервисам в compose файле.
Убедиться что лимиты применились.

```yaml
services:
  app:
    image: nginx:alpine
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 128M
        reservations:
          memory: 64M
```

```bash
docker compose up -d
docker stats --no-stream   # посмотреть лимиты и использование
docker inspect <container> | jq '.[0].HostConfig | {Memory, CpuQuota}'
```
