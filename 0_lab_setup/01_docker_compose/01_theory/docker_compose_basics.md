# Docker Compose — основы для лабораторных стендов

Docker Compose — инструмент для запуска многоконтейнерных приложений.
В этой базе он используется как **Tier-1 лаба**: поднимаешь стенд одной командой,
выполняешь упражнение, останавливаешь.

## Установка

```bash
# Linux — Docker Engine + Compose plugin
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER   # добавить себя в группу docker (нужен relogin)
docker compose version          # убедиться что compose v2 установлен

# Fedora/RHEL
sudo dnf install docker-ce docker-compose-plugin
sudo systemctl enable --now docker

# macOS — Docker Desktop или OrbStack
brew install orbstack             # рекомендуется: быстрее и легче Docker Desktop

# Windows — Docker Desktop + WSL2 backend
# https://docs.docker.com/desktop/install/windows-install/
```

## Структура compose файла

```yaml
# docker-compose.yml
services:
  app:
    image: nginx:alpine           # готовый образ
    # build: .                    # или сборка из Dockerfile в текущей папке
    ports:
      - "8080:80"                 # host:container
    environment:
      - ENV_VAR=value
    env_file:
      - .env                      # переменные из файла
    volumes:
      - ./config:/etc/nginx/conf.d:ro   # bind mount (host:container)
      - app_data:/var/lib/data          # named volume
    depends_on:
      db:
        condition: service_healthy  # ждать healthcheck db
    networks:
      - backend
    restart: unless-stopped

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: mydb
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
    volumes:
      - pg_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d mydb"]
      interval: 5s
      timeout: 3s
      retries: 5
    networks:
      - backend

volumes:
  pg_data:      # named volume, управляется Docker
  app_data:

networks:
  backend:      # изолированная сеть, контейнеры находят друг друга по имени сервиса
```

## Команды

```bash
# запустить все сервисы в фоне
docker compose up -d

# запустить только один сервис (и его зависимости)
docker compose up -d db

# посмотреть статус
docker compose ps

# логи всех сервисов
docker compose logs -f

# логи одного сервиса
docker compose logs -f app

# выполнить команду внутри контейнера
docker compose exec db psql -U user -d mydb

# остановить без удаления данных
docker compose stop

# остановить и удалить контейнеры + сети (данные в volumes сохраняются)
docker compose down

# удалить всё включая volumes (сброс в чистое состояние)
docker compose down -v

# пересобрать образ и перезапустить
docker compose up -d --build app

# посмотреть итоговый конфиг (с подстановкой переменных)
docker compose config
```

## Override файлы (для разных окружений)

```bash
# docker-compose.yml       — базовая конфигурация
# docker-compose.override.yml  — накладывается автоматически при compose up
# docker-compose.prod.yml  — явно:

docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

## Паттерн стендов в этой базе

Каждый стенд живёт в папке `03_exercises/NN_название/`:

```
03_exercises/01_prometheus_basics/
├── docker-compose.yml     # поднять: docker compose up -d
├── .env.example           # скопировать в .env перед запуском
└── README.md              # задание + как проверить результат
```

Стандартный цикл:
```bash
cd 03_exercises/01_prometheus_basics/
cp .env.example .env
docker compose up -d
# ... выполняешь упражнение ...
docker compose down -v   # сбросить стенд
```
