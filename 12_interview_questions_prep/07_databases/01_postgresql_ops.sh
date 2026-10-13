# 1. Что такое Patroni и зачем он нужен?
Patroni — агент, который запускается рядом с каждым узлом Postgres и
автоматически управляет кластером: следит, кто сейчас primary,
и переключает реплику в primary, если текущий primary упал. Сам
Postgres этого не умеет — без Patroni (или аналогов вроде repmgr)
переключение пришлось бы делать руками.

# 2. Из чего состоит конфиг Patroni (patroni.yml) и что в нем
настраивается?
Основные секции:
- `scope` / `namespace` — имя кластера (чтобы несколько кластеров
  Patroni не перепутались в одном DCS).
- `restapi` — порт, на котором Patroni отдает статус узла
  (`/primary`, `/replica`) — именно эти эндпоинты потом опрашивает
  HAProxy (см. вопрос 5).
- `etcd` (или `consul`/`zookeeper`) — адреса узлов хранилища
  консенсуса, где Patroni хранит, кто сейчас лидер.
- `bootstrap.dcs` — таймауты кластера: `ttl` (сколько лидер может не
  отвечать, прежде чем его сочтут упавшим), `loop_wait` (как часто
  Patroni проверяет состояние), `retry_timeout`.
- `postgresql` — путь к бинарникам, `data_dir`, параметры подключения,
  и `parameters:` — отсюда Patroni сам генерирует нужные строки в
  `postgresql.conf` (например `wal_level: replica`,
  `max_wal_senders: 10`) — руками эти параметры менять не нужно,
  Patroni следит, чтобы они были одинаковы на всех узлах.

# 3. Что такое PgBouncer и зачем он нужен, если есть Patroni?
Это разные задачи. Patroni решает "кто сейчас primary". PgBouncer —
легковесный пул соединений: каждое новое соединение к Postgres —
это отдельный процесс ОС, что дорого при тысячах клиентов. PgBouncer
держит небольшое число реальных соединений к Postgres открытыми и
раздает их клиентам по очереди, вместо того чтобы Postgres открывал
отдельный процесс на каждого клиента.

# 4. Что настраивается в конфиге PgBouncer (pgbouncer.ini)?
```ini
[databases]
mydb = host=127.0.0.1 port=5432 dbname=mydb

[pgbouncer]
listen_port = 6432
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 20
auth_type = md5
auth_file = /etc/pgbouncer/userlist.txt
```
- `[databases]` — куда реально стучаться (адрес настоящего Postgres).
- `pool_mode` — `transaction` (самый частый выбор: соединение
  возвращается в пул сразу после COMMIT) vs `session` (держит
  соединение на все время сессии клиента).
- `max_client_conn` — сколько клиентов может подключиться к самому
  PgBouncer.
- `default_pool_size` — сколько РЕАЛЬНЫХ соединений к Postgres
  держать на одну базу — вот тут и есть экономия.
- `auth_file` — отдельный файл с логинами/хэшами паролей для
  проверки клиентов.

# 5. Как объединить несколько хостов Postgres и сделать к ним
балансировку?
Схема: Patroni на каждом узле управляет ролями → HAProxy спереди
опрашивает REST API Patroni (`GET /primary`, `GET /replica` — см.
вопрос 2) и держит два порта: один всегда ведет на текущий primary
(для записи), второй — на все здоровые реплики по очереди (для
чтения). Приложение подключается не к конкретному серверу Postgres,
а к нужному порту HAProxy.
```
# haproxy.cfg, сокращенно
listen postgres_primary
    bind *:5000
    option httpchk GET /primary
    http-check expect status 200
    server pg1 10.0.0.1:5432 check port 8008
    server pg2 10.0.0.2:5432 check port 8008
    server pg3 10.0.0.3:5432 check port 8008

listen postgres_replicas
    bind *:5001
    option httpchk GET /replica
    http-check expect status 200
    balance roundrobin
    server pg1 10.0.0.1:5432 check port 8008
    server pg2 10.0.0.2:5432 check port 8008
    server pg3 10.0.0.3:5432 check port 8008
```
Порт 8008 — это `restapi` порт Patroni из вопроса 2: HAProxy не
проверяет сам Postgres напрямую, а спрашивает Patroni "ты сейчас
primary или реплика?".

# 6. В каком порядке обычно идет цепочка от приложения до Postgres в
такой схеме?
Приложение → PgBouncer (пул соединений) → HAProxy (кто сейчас
primary/реплика) → Patroni на узле → сам процесс Postgres. PgBouncer
и HAProxy можно поставить и в обратном порядке (HAProxy → PgBouncer
на каждом узле) — частый практический вопрос на собеседовании просто
"нарисуй эту цепочку и объясни, зачем каждый компонент".

# 7. Какие расширения (extensions) для Postgres чаще всего ставят
отдельно?
- `pg_stat_statements` — статистика по всем запросам (кто/сколько
  раз/среднее время) — обычно включают сразу в проде.
- `pg_cron` — запуск SQL-задач по расписанию прямо внутри Postgres,
  без внешнего cron: `SELECT cron.schedule('0 3 * * *', 'VACUUM
  ANALYZE orders')`.
- `pg_partman` — автоматическое управление партициями по
  дате/диапазону (создание новых партиций заранее, удаление старых).
- `PostGIS` — геопространственные данные и запросы (расстояния,
  полигоны).
- `TimescaleDB` — превращает обычную таблицу в оптимизированную под
  временные ряды (автоматическое партиционирование по времени,
  быстрые агрегаты).
Ставятся так: `CREATE EXTENSION pg_cron;` после установки пакета в
ОС — сама СУБД из коробки их не содержит.

# 8. Что обычно тюнят в `postgresql.conf`, кроме репликации?
```conf
shared_buffers = 4GB
work_mem = 64MB
effective_cache_size = 12GB
autovacuum_vacuum_scale_factor = 0.1
autovacuum_max_workers = 3
```
- `shared_buffers` — сколько памяти Postgres держит под свой кэш
  страниц (обычно 25% RAM сервера).
- `work_mem` — память на одну операцию сортировки/хэширования
  (слишком большое значение при многих параллельных запросах может
  исчерпать RAM — лимит действует НА КАЖДУЮ операцию, не глобально).
- `autovacuum_vacuum_scale_factor` — при какой доле "мёртвых" строк
  в таблице автовакуум запускается (0.1 = после 10% изменений).
  Для больших таблиц часто уменьшают, иначе вакуум запускается
  слишком редко.

# 9. Как мониторить Postgres?
`postgres_exporter` для Prometheus — читает `pg_stat_*` системные
представления (`pg_stat_activity`, `pg_stat_replication`,
`pg_stat_statements` из вопроса 7) и отдает метрики наружу. Смотрят
в первую очередь: число активных соединений (не уперлись ли в
`max_connections`), лаг репликации (`pg_stat_replication.
replay_lag`), долю кэш-попаданий (`pg_stat_database` —
`blks_hit`/`blks_read`).

# 10. Как настроить логическую репликацию (не всей БД, а конкретных
таблиц)?
```sql
-- на источнике
CREATE PUBLICATION my_pub FOR TABLE orders, customers;

-- на приемнике
CREATE SUBSCRIPTION my_sub
  CONNECTION 'host=pg1 dbname=mydb user=repl_user'
  PUBLICATION my_pub;
```
В отличие от обычной потоковой репликации, которой управляет Patroni
(реплика — полная побайтовая копия всей базы), логическая репликация
копирует только указанные таблицы, работает между разными мажорными
версиями Postgres, и в приемник можно параллельно писать из других
источников — используется для миграций без простоя и агрегации
данных из нескольких БД в одну аналитическую.
