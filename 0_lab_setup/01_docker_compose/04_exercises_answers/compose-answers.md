# Ответы — Docker Compose

Номера и названия совпадают с [03_exercises/README.md](../03_exercises/README.md).

## Упражнение 1 — Поднять стек app + db + healthcheck

Готовое решение — стенд [02_examples/full-stack.yaml](../02_examples/full-stack.yaml)
(nginx → Flask-приложение → PostgreSQL + Redis). Ключевые места:
`healthcheck.test: ["CMD-SHELL", "pg_isready -U user -d appdb"]` у `db` и
`depends_on.db.condition: service_healthy` у `app`.

```bash
cd ../02_examples/
docker compose -f full-stack.yaml up -d
docker compose -f full-stack.yaml ps
curl -s http://localhost/
docker compose -f full-stack.yaml logs db | tail -n 3
```

Ожидаемый вывод (примерно так):

```text
NAME                 SERVICE  STATUS
02_examples-app-1    app      Up 10 seconds
02_examples-cache-1  cache    Up 16 seconds
02_examples-db-1     db       Up 16 seconds (healthy)
02_examples-nginx-1  nginx    Up 9 seconds
{"postgres":"PostgreSQL 16.x on x86_64-pc-linux-musl, ...","visits":1}
db-1  | ... database system is ready to accept connections
```

Почему так: `service_healthy` ждёт, пока `pg_isready` вернёт 0, а не просто
старт контейнера — иначе app падает на первом коннекте к ещё не готовой БД.
`app` и `nginx` находят `db`/`cache`/`app` по имени сервиса через DNS
compose-сети.

## Упражнение 2 — Override файлы для dev и prod

Файлы решения — в [02_override/](./02_override/):
[docker-compose.yml](./02_override/docker-compose.yml) (база: только
`image`), [docker-compose.override.yml](./02_override/docker-compose.override.yml)
(dev: `build: .`, bind mount `./site`, порты 8000 и debug 5678),
[docker-compose.prod.yml](./02_override/docker-compose.prod.yml) (prod:
готовый образ, `restart`, лимиты CPU/памяти).

```bash
cd 02_override/
docker compose up -d --build        # dev: base + override автоматически
curl -s http://localhost:8000/
docker compose down

docker compose -f docker-compose.yml -f docker-compose.prod.yml config
```

Ожидаемый вывод (примерно так):

```text
<h1>lab web</h1>
...
services:
  web:
    deploy:
      resources:
        limits:
          cpus: 0.5
          memory: "134217728"
    restart: unless-stopped
    image: lab/web:1.0
    ports:
      - target: 8000
        published: "80"
```

Почему так: без `-f` compose читает `docker-compose.yml` и
`docker-compose.override.yml`; с явными `-f` override не подхватывается.
В prod-конфиге нет `build` и bind mount — запускается ровно тот образ,
который прошёл CI. `docker compose config` — способ увидеть итог слияния.

## Упражнение 3 — Profiles

Решение — [03_profiles/docker-compose.yml](./03_profiles/docker-compose.yml):
у `prometheus` и `grafana` стоит `profiles: [monitoring]`. Рядом лежат
[prometheus.yml](./03_profiles/prometheus.yml) и provisioning datasource
[grafana/provisioning/datasources/prometheus.yaml](./03_profiles/grafana/provisioning/datasources/prometheus.yaml).

```bash
cd 03_profiles/
docker compose up -d
docker compose ps --format '{{.Service}}'
docker compose --profile monitoring up -d
docker compose --profile monitoring ps --format '{{.Service}}'
curl -s http://localhost:9090/-/ready
docker compose --profile monitoring down
```

Ожидаемый вывод (примерно так):

```text
web
grafana
prometheus
web
Prometheus Server is Ready.
```

Почему так: сервис с `profiles` не стартует, пока профиль не включён
(`--profile` или `COMPOSE_PROFILES=monitoring`). Сервис без `profiles`
запускается всегда. `down` тоже нужен с `--profile`, иначе сервисы профиля
останутся.

## Упражнение 4 — Очистка и инспекция

```bash
docker system df
docker volume ls
cd ../02_examples/
docker compose -f full-stack.yaml down -v
docker volume ls | grep 02_examples
docker system prune -a --volumes
```

Ожидаемый вывод (примерно так):

```text
TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
Images          12        4         2.1GB     1.4GB (66%)
Containers      4         4         1.2MB     0B (0%)
Local Volumes   2         2         48MB      0B (0%)
Build Cache     30        0         310MB     310MB
DRIVER    VOLUME NAME
local     02_examples_pg_data
local     02_examples_redis_data
 ✔ Volume 02_examples_pg_data    Removed
 ✔ Volume 02_examples_redis_data Removed
WARNING! This will remove:
  - all stopped containers
  ...
Are you sure you want to continue? [y/N]
```

Почему так: `down -v` удаляет именованные volumes этого проекта — сброс
стенда в чистое состояние (данные PostgreSQL пропадут). `system prune -a
--volumes` чистит всё неиспользуемое на машине, включая образы и volumes
других проектов, поэтому команда спрашивает подтверждение.
