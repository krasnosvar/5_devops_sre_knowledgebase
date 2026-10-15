# Docker Compose для стендов — шпаргалка

Подробности и объяснения — в
[docker_compose_basics.md](./01_theory/docker_compose_basics.md).
⚠️ — опасная команда или частая ловушка.

## Установка и проверка

| Задача | Команда |
| :--- | :--- |
| Поставить Engine + Compose plugin (Linux) | `curl -fsSL https://get.docker.com \| sh` |
| Fedora/RHEL | `sudo dnf install docker-ce docker-compose-plugin`<br>`sudo systemctl enable --now docker` |
| Работать без `sudo` (нужен relogin) ⚠️ группа `docker` = root на хосте | `sudo usermod -aG docker $USER` |
| Проверить, что стоит Compose v2 (плагин) | `docker compose version` |
| macOS | `brew install orbstack` или Docker Desktop |

## Жизненный цикл стенда

| Задача | Команда |
| :--- | :--- |
| Поднять всё в фоне | `docker compose up -d` |
| Поднять один сервис (+ его `depends_on`) | `docker compose up -d db` |
| Пересобрать образ и перезапустить | `docker compose up -d --build app` |
| Статус | `docker compose ps` (включая остановленные: `ps -a`) |
| Логи всех / одного сервиса | `docker compose logs -f` / `docker compose logs -f app` |
| Последние N строк | `docker compose logs --tail 100 app` |
| Команда внутри работающего контейнера | `docker compose exec db psql -U user -d mydb` |
| Разовая команда в новом контейнере | `docker compose run --rm app sh` |
| Остановить, ничего не удаляя | `docker compose stop` |
| Удалить контейнеры и сети (volumes живы) | `docker compose down` |
| Сброс в чистое состояние ⚠️ удаляет named volumes | `docker compose down -v` |
| Итоговый конфиг (merge + подстановка `${VAR}`) | `docker compose config` |
| Только проверить синтаксис | `docker compose config -q` |
| Несколько файлов (override) | `docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d` |

## Каркас compose-файла

```yaml
services:                         # ключ version: не нужен (устарел)
  app:
    image: nginx:alpine           # или build: .
    ports: ["8080:80"]            # host:container
    env_file: [.env]              # переменные внутрь контейнера
    volumes:
      - ./config:/etc/nginx/conf.d:ro   # bind mount
      - app_data:/var/lib/data          # named volume
    depends_on:
      db: { condition: service_healthy }
    restart: unless-stopped
  db:
    image: postgres:16-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d mydb"]
      interval: 5s
      timeout: 3s
      retries: 5
volumes:
  app_data:
```

## Какие файлы читаются

| Файл | Когда применяется |
| :--- | :--- |
| `docker-compose.yml` / `compose.yaml` | всегда — базовый |
| `docker-compose.override.yml` | автоматически поверх базового при `up` без `-f` |
| `docker-compose.prod.yml` | только явно через `-f` |
| `.env` рядом с файлом | подстановка `${VAR}` в YAML, внутрь контейнера не попадает |

## Типичный цикл лабы

| Шаг | Команда |
| :--- | :--- |
| Перейти к стенду темы | `cd <тема>/02_examples/` |
| Поднять | `docker compose up -d` |
| Сбросить после упражнения | `docker compose down -v` |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| `permission denied ... docker.sock` | нет в группе `docker` или не перелогинились: `id` |
| `port is already allocated` | порт хоста занят: `ss -ltnp \| grep 8080` |
| Сервис ждёт `db` вечно | healthcheck падает: `docker compose ps` (health), `docker inspect --format '{{json .State.Health}}' <container>` |
| Правки в коде не видны | образ не пересобран — `up -d --build` |
| Данные пропали после `down` | БД без named volume или запускали `down -v` |
| Переменная пустая в YAML | нет в `.env`/окружении — смотреть `docker compose config` |

> Проверка: команды и флаги сверены с `docker compose <cmd> --help`
> (Docker 29.9, Compose v5.6), каркас — `docker compose config -q`;
> не проверено: установка через `get.docker.com`, `dnf`, `brew`.
