# 1. Что такое Replica Set и как его настроить?
Группа узлов MongoDB (обычно 3), хранящих одинаковые данные: один
Primary принимает запись, остальные Secondary реплицируют её через
oplog. Если Primary падает, остальные узлы сами выбирают нового
(без внешнего оркестратора вроде Patroni — это встроено в MongoDB).
```js
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "mongo1:27017" },
    { _id: 1, host: "mongo2:27017" },
    { _id: 2, host: "mongo3:27017" }
  ]
})
```

# 2. Что настраивается в `mongod.conf`?
```yaml
net:
  port: 27017
storage:
  dbPath: /var/lib/mongodb
  wiredTiger:
    engineConfig:
      cacheSizeGB: 4
replication:
  replSetName: rs0
sharding:
  clusterRole: shardsvr
```
- `storage.wiredTiger.engineConfig.cacheSizeGB` — сколько памяти
  движку хранения держать под кэш данных (по умолчанию ~50% RAM —
  на выделенном под Mongo сервере обычно уменьшают, если на той же
  машине что-то еще работает).
- `replication.replSetName` — имя Replica Set, с которым узел
  присоединяется.
- `sharding.clusterRole` — `shardsvr` (это один из шардов) или
  `configsvr` (это узел Config Server, см. вопрос 4).

# 3. Что такое Sharded Cluster и когда к нему переходят вместо
обычного Replica Set?
Replica Set — полные копии одних и тех же данных (про
отказоустойчивость и чтение). Sharded Cluster — разные данные на
разных шардах (про объём данных и нагрузку записи, которая не
помещается на один сервер). Переходят, когда данные/запись реально
упираются в возможности одного сервера — не "на всякий случай".

# 4. Из каких частей состоит Sharded Cluster?
- **Shard** — хранит часть данных (сам обычно Replica Set).
- **Config Servers** — отдельный Replica Set, хранящий, какой чанк
  данных лежит на каком шарде.
- **mongos** — роутер, к которому подключается приложение; сам
  данные не хранит, читает карту у Config Servers и шлет запрос на
  нужный шард.
```js
sh.addShard("shard1/mongo1:27017,mongo2:27017,mongo3:27017")
sh.enableSharding("mydb")
sh.shardCollection("mydb.events", { user_id: 1 })
```
Последняя команда — ключ шардирования (`user_id`): по нему решается,
в какой шард попадет документ. Поменять его для существующей
коллекции без миграции данных нельзя — выбирают один раз, заранее.

# 5. Какие индексы чаще всего настраивают в проде, кроме обычного
`createIndex`?
- **TTL-индекс** — документы удаляются сами через заданное время:
  `db.sessions.createIndex({createdAt: 1}, {expireAfterSeconds: 3600})`.
- **Составной (compound) индекс** — под конкретный паттерн запроса:
  `db.orders.createIndex({user_id: 1, status: 1})`.
- **Текстовый индекс** — полнотекстовый поиск:
  `db.articles.createIndex({body: "text"})`.
Посмотреть, какой индекс реально используется в запросе:
`db.orders.find({...}).explain("executionStats")`.

# 6. Как настроить Read Preference, чтобы читать с реплик, не
ставя балансировщик перед кластером?
Указывается на стороне клиента/драйвера, без внешнего прокси:
```js
db.collection.find().readPref("secondaryPreferred")
```
`primary` (по умолчанию) / `secondaryPreferred` (читать с реплик,
разгружая Primary) / `nearest` (минимальная задержка). Драйвер сам
знает топологию Replica Set — в отличие от Postgres, отдельный
HAProxy для этого не нужен.

# 7. Как мониторить MongoDB?
`mongostat` (как top, но по операциям: inserts/query/update в
секунду) и `mongotop` (какие коллекции отнимают больше всего
времени чтения/записи) — быстрый ручной взгляд. Для постоянного
мониторинга — `mongodb_exporter` для Prometheus, собирает метрики
через встроенный `serverStatus()`/`dbStats()`.

# 8. Как сделать бэкап MongoDB?
`mongodump`/`mongorestore` — логический бэкап (экспорт документов в
BSON), работает на любой версии, но медленный на больших базах.
Для больших продакшен-баз обычно используют снэпшоты файловой
системы (LVM/облачные snapshot) директории `dbPath` — быстрее, но
требует консистентности (сначала `fsyncLock()`, чтобы остановить
запись на диск на момент снэпшота, потом `fsyncUnlock()`).

# 9. Какие есть расширения/плагины у MongoDB, которые часто
ставят отдельно?
MongoDB Enterprise добавляет аудит-логирование и LDAP-авторизацию
(в Community-версии их нет). Отдельно часто подключают
`mongodb-kafka-connector` (Kafka Connect source/sink — стримить
изменения через Change Streams в Kafka) и Percona Backup for
MongoDB (PBM) как open-source альтернативу встроенным инструментам
бэкапа с поддержкой инкрементальных бэкапов шардированного кластера.
