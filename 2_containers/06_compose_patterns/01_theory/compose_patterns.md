# Docker Compose паттерны

## Healthcheck и depends_on

```yaml
services:
  db:
    image: postgres:16-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-postgres}"]
      interval: 5s
      timeout: 3s
      retries: 10
      start_period: 10s   # не проверять первые 10с после старта

  app:
    image: myapp:latest
    depends_on:
      db:
        condition: service_healthy   # ждать пока db не пройдёт healthcheck
      redis:
        condition: service_started   # просто ждать запуска (без healthcheck)
```

## Override файлы

```yaml
# docker-compose.yml — базовый (в репо)
services:
  app:
    image: myapp:${APP_VERSION:-latest}
    environment:
      - LOG_LEVEL=info

# docker-compose.override.yml — для локальной разработки (в .gitignore)
services:
  app:
    build: .            # собирать локально вместо образа
    volumes:
      - .:/app          # hot reload
    environment:
      - LOG_LEVEL=debug
    ports:
      - "8080:8080"

# docker-compose.prod.yml — для production
services:
  app:
    restart: always
    deploy:
      resources:
        limits:
          memory: 512m
```

```bash
# compose автоматически подхватывает override.yml
docker compose up -d

# явно указать несколько файлов
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

## Profiles — запускать только нужные сервисы

```yaml
services:
  app:
    image: myapp:latest
    # без profile — запускается всегда

  db:
    image: postgres:16
    # без profile — запускается всегда

  pgadmin:
    image: dpage/pgadmin4
    profiles: [debug]   # только при --profile debug

  prometheus:
    image: prom/prometheus
    profiles: [monitoring]
```

```bash
docker compose up -d                       # только app + db
docker compose --profile debug up -d      # + pgadmin
docker compose --profile monitoring up -d # + prometheus
```

## Полный типовой стенд

```yaml
# docker-compose.yml для лабораторного стенда (app + postgres + redis + nginx)
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certs:/etc/nginx/certs:ro
    depends_on:
      - app
    restart: unless-stopped

  app:
    build:
      context: .
      dockerfile: Dockerfile
      target: production
    environment:
      DATABASE_URL: postgresql://app:secret@db:5432/appdb
      REDIS_URL: redis://redis:6379/0
      SECRET_KEY: ${SECRET_KEY}
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    restart: unless-stopped

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: appdb
      POSTGRES_USER: app
      POSTGRES_PASSWORD: secret
    volumes:
      - pg_data:/var/lib/postgresql/data
      - ./db/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d appdb"]
      interval: 5s
      retries: 10
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes --maxmemory 256mb --maxmemory-policy allkeys-lru
    volumes:
      - redis_data:/data
    restart: unless-stopped

volumes:
  pg_data:
  redis_data:

networks:
  default:
    name: myapp-network
```

## Полезные команды для стендов

```bash
# запустить и следить за логами
docker compose up

# в фоне
docker compose up -d

# пересобрать образ перед запуском
docker compose up -d --build app

# посмотреть состояние
docker compose ps

# логи конкретного сервиса
docker compose logs -f app

# перезапустить один сервис
docker compose restart app

# выполнить команду
docker compose exec db psql -U app -d appdb

# полный сброс (удалить контейнеры + volumes)
docker compose down -v

# только остановить
docker compose stop
```
