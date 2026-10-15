# Ответы — упражнения Docker Compose Patterns

Упражнения: [03_exercises/README.md](../03_exercises/README.md).

## Упражнение 01 — Healthcheck + depends_on

Исправленный файл — [docker-compose.answer.yml](./docker-compose.answer.yml)
(это и есть `good-compose.yml`).

```bash
docker compose -f bad-compose.yml up --abort-on-container-exit --exit-code-from app
docker compose -f bad-compose.yml down -v

cp docker-compose.answer.yml good-compose.yml
docker compose -f good-compose.yml up --abort-on-container-exit --exit-code-from app
docker compose -f good-compose.yml down -v
```

Ожидаемый вывод (примерно так):

```text
app-1  | psql: error: connection to server at "db" (172.20.0.2), port 5432 failed: Connection refused
app-1  | 	Is the server running on that host and accepting TCP/IP connections?
app-1 exited with code 2
...
app-1  |   ?column?
app-1  | ------------
app-1  |  Connected!
app-1 exited with code 0
```

Почему так: короткий `depends_on: [db]` ждёт только старта контейнера, а
postgres ещё несколько секунд инициализирует кластер. `condition:
service_healthy` ждёт, пока healthcheck (`pg_isready`) вернёт успех.
`-h 127.0.0.1` в healthcheck — чтобы проверять TCP, а не временный сервер
на unix-сокете, который entrypoint поднимает на время инициализации.

## Упражнение 02 — Именованные volumes и backup

`compose.yaml` — из условия (volume `postgres_data` с фиксированным `name:`).

```bash
docker compose up -d --wait db
docker compose exec db psql -U postgres -c "CREATE TABLE test (id serial, val text);"
docker compose exec db psql -U postgres -c "INSERT INTO test(val) VALUES ('hello from exercise 02');"

docker compose stop db
docker run --rm -v postgres_data:/source:ro -v "$(pwd)":/backup \
  alpine tar czf /backup/pg-backup.tar.gz -C /source .

docker compose down -v
docker compose create db
docker run --rm -v postgres_data:/target -v "$(pwd)":/backup:ro \
  alpine tar xzf /backup/pg-backup.tar.gz -C /target

docker compose up -d --wait db
docker compose exec db psql -U postgres -c "SELECT * FROM test;"
docker compose down -v
```

Ожидаемый вывод (примерно так):

```text
CREATE TABLE
INSERT 0 1
 Container ...-db-1  Stopped
 Container ...-db-1  Created
 Container ...-db-1  Healthy
 id |          val
----+------------------------
  1 | hello from exercise 02
(1 row)
```

Почему так: без `name:` compose создал бы volume `<проект>_postgres_data`, и
`-v postgres_data:...` указывал бы на другой, пустой volume. Копировать файлы
нужно при остановленном postgres, иначе архив может быть неконсистентным
(для живой БД — `pg_dump`). Восстанавливать — до первого старта postgres:
`create` создаёт volume, но не запускает entrypoint, который иначе
инициализировал бы пустой кластер.

## Упражнение 03 — Profiles: опциональные сервисы

```bash
docker compose up -d
docker compose ps --format '{{.Service}}'
docker compose --profile debug up -d
docker compose ps --format '{{.Service}}'
docker compose --profile debug --profile monitoring up -d
docker compose ps --format '{{.Service}}'
docker compose --profile debug --profile monitoring down
```

Ожидаемый вывод (примерно так):

```text
app
adminer
app
adminer
app
prometheus
```

Почему так: сервис с `profiles:` запускается только при явном
`--profile <имя>` (или `COMPOSE_PROFILES`); сервисы без `profiles` стартуют
всегда. При `down` нужно передать те же профили, иначе профильные сервисы
останутся запущенными.

## Упражнение 04 — Resource limits в compose

```bash
docker compose up -d
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}\t{{.CPUPerc}}'
docker inspect "$(docker compose ps -q app)" \
  | jq '.[0].HostConfig | {Memory, MemoryReservation, NanoCpus}'
docker compose down
```

Ожидаемый вывод (примерно так):

```text
NAME        MEM USAGE / LIMIT   CPU %
...-app-1   17MiB / 128MiB      0.00%
{
  "Memory": 134217728,
  "MemoryReservation": 67108864,
  "NanoCpus": 500000000
}
```

Почему так: `deploy.resources` в Compose v2 применяется и без Swarm:
`limits.memory` → `memory.max` в cgroup (OOM kill при превышении),
`reservations.memory` → мягкий лимит, `limits.cpus` → `NanoCpus` (квота CPU
в cgroup `cpu.max`; поле `CpuQuota` при этом остаётся 0).
