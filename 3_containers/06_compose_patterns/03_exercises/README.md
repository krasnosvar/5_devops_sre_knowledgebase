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
    # клиент psql из того же образа — стартует мгновенно, без установки пакетов
    image: postgres:16-alpine
    environment:
      PGPASSWORD: test
    command: psql -h db -U postgres -c "SELECT 'Connected!'"
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

`compose.yaml` для упражнения (volume с фиксированным именем, иначе compose
добавит к нему префикс проекта):

```yaml
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: test
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -h 127.0.0.1 -U postgres"]
      interval: 3s
      retries: 10
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
    name: postgres_data
```

```bash
# Поднять postgres и дождаться healthcheck
docker compose up -d --wait db

# Записать данные
docker compose exec db psql -U postgres -c "CREATE TABLE test (id serial, val text);"
docker compose exec db psql -U postgres -c "INSERT INTO test(val) VALUES ('hello from exercise 02');"

# Остановить БД (копия файлов работающего postgres может быть
# неконсистентной) и сделать backup volume в tar архив
docker compose stop db
docker run --rm \
  -v postgres_data:/source:ro \
  -v $(pwd):/backup \
  alpine tar czf /backup/pg-backup.tar.gz -C /source .

# Удалить всё включая volume
docker compose down -v

# Восстановить данные из бэкапа: create создаёт volume и контейнер,
# но не запускает postgres (иначе он успеет инициализировать пустую БД)
docker compose create db
docker run --rm \
  -v postgres_data:/target \
  -v $(pwd):/backup:ro \
  alpine tar xzf /backup/pg-backup.tar.gz -C /target

# Запустить и проверить данные
docker compose up -d --wait db
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
# cpus: "0.5" Docker хранит в NanoCpus (CpuQuota останется 0)
docker inspect <container> | jq '.[0].HostConfig | {Memory, MemoryReservation, NanoCpus}'
```
