# Паттерны Docker Compose — шпаргалка

Подробности и объяснения — в
[compose_patterns.md](./01_theory/compose_patterns.md). Базовые команды
стенда — в
[0_lab_setup/01_docker_compose](../../0_lab_setup/01_docker_compose/CHEATSHEET.md).
⚠️ — опасная команда или частая ловушка.

## Команды сверх базовых

| Задача | Команда |
| :--- | :--- |
| Поднять и дождаться healthy | `docker compose up -d --wait` |
| Включить профиль(и) | `docker compose --profile ml up -d` (несколько: `--profile a --profile b`) |
| Масштабировать сервис | `docker compose up -d --scale web=3` |
| Разовая задача (порты не публикуются) | `docker compose run --rm web bash` |
| Тест-стенд: упасть, когда упал `app`, и вернуть его код | `docker compose up --abort-on-container-exit --exit-code-from app` |
| Другое имя проекта (префикс сетей/томов) | `docker compose -p myproj up -d` |
| Список сервисов | `docker compose config --services` |
| Перезапуск без пересоздания | `docker compose restart app` (новый env/образ не подхватит) |
| Пересоздать, даже если конфиг не менялся | `docker compose up -d --force-recreate app` |
| Удалить контейнеры сервисов, которых больше нет в YAML | `docker compose up -d --remove-orphans` |

## `.env` vs `env_file` vs `environment`

| Механизм | Кто читает | Куда попадает |
| :--- | :--- | :--- |
| `.env` рядом с compose-файлом | `docker compose` при парсинге | только подстановка `${VAR}` в YAML |
| `env_file: [.env.prod]` | `docker compose` | в окружение процесса контейнера |
| `environment: [AWS_SECRET_KEY]` (без значения) | из shell хоста | в контейнер, не записываясь в файлы |
| Значение по умолчанию | — | `image: myapp:${VERSION:-latest}` |
| Обязательная переменная | — | `${DB_PASS:?нужен DB_PASS}` — ошибка, если не задана |

## Порядок запуска

```yaml
services:
  db:
    image: postgres:16-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user"]
      interval: 5s
      retries: 5
  backend:
    image: myapp
    depends_on:
      db:
        condition: service_healthy   # иначе ждёт только старта контейнера
```

| `condition` | Ждёт |
| :--- | :--- |
| `service_started` (как `depends_on: [db]`) | старта контейнера, не готовности процесса |
| `service_healthy` | успешного `healthcheck` |
| `service_completed_successfully` | завершения с кодом 0 (миграции, init) |

## Override и профили

| Механизм | Как работает |
| :--- | :--- |
| `docker-compose.override.yml` | подхватывается автоматически, merge поверх базового |
| Скаляры (`image`, `command`) | перезаписываются из override |
| Списки (`ports`, `expose`) | объединяются |
| `profiles: ["ml"]` у сервиса | без `--profile ml` сервис не стартует |
| Проверить итог merge | `docker compose config` |

## Сети и тома

| Факт | Значение |
| :--- | :--- |
| Сеть по умолчанию | `<project>_default`, project = имя каталога |
| Обращение между сервисами | по имени сервиса: `db:5432` (встроенный DNS) |
| Named volumes | переживают `down`, удаляются только `down -v` ⚠️ |
| Лимиты ресурсов | `deploy.resources.limits: {cpus: "1", memory: 512M}` |
| Ротация логов | `logging: {driver: json-file, options: {max-size: 10m, max-file: "3"}}` |

## Подвохи

| ⚠️ | Суть |
| :--- | :--- |
| `--scale` + `ports: ["8080:80"]` | `port is already allocated` — не публиковать порт или `ports: ["80"]` |
| `restart` после правки `.env` | не применит — нужен `up -d` (пересоздание) |
| Данные пропали после `down` | у БД не было named volume |
| `docker-compose` (через дефис) | Compose v1 на Python, не поддерживается |
| Код изменился, контейнер старый | `up -d --build` |

> Проверка: флаги сверены с `docker compose <cmd> --help` (Compose
> v5.6), YAML и `${VAR:?}` — `docker compose config -q` в scratch;
> не проверено: —.
