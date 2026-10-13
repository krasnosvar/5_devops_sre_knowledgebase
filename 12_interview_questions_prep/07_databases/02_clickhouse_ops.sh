# 1. Что такое ReplicatedMergeTree и зачем он нужен?
Обычный MergeTree хранит данные только на одном узле — при его
падении данные теряются. ReplicatedMergeTree — тот же движок, но с
репликацией: вставки регистрируются в ClickHouse Keeper (или
ZooKeeper), а остальные реплики видят новую запись через Keeper и
скачивают данные друг у друга напрямую.

# 2. Что такое Distributed-таблица и как через нее читают данные со
всех шардов сразу?
Distributed — это не таблица с данными, а "вид" поверх кластера:
при SELECT она сама рассылает под-запросы на все шарды (из конфига
`remote_servers`) и собирает результат. Реальные данные лежат в
обычных ReplicatedMergeTree на каждом шарде отдельно.

# 3. Как выглядит конфиг кластера (`remote_servers` в config.xml)?
```xml
<remote_servers>
    <my_cluster>
        <shard>
            <replica>
                <host>ch1</host>
                <port>9000</port>
            </replica>
            <replica>
                <host>ch2</host>
                <port>9000</port>
            </replica>
        </shard>
        <shard>
            <replica>
                <host>ch3</host>
                <port>9000</port>
            </replica>
        </shard>
    </my_cluster>
</remote_servers>
```
Каждый `<shard>` — кусок данных, каждый `<replica>` внутри шарда —
его копия. Таблицу создают так:
```sql
CREATE TABLE events ON CLUSTER my_cluster (...)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/events', '{replica}')
ORDER BY ts;

CREATE TABLE events_dist AS events
ENGINE = Distributed(my_cluster, default, events, rand());
```
`rand()` в конце — ключ шардирования: по какому выражению решать, в
какой шард класть строку.

# 4. Какие основные конфиг-файлы у ClickHouse и за что каждый
отвечает?
- `config.xml` — сам сервер: порты, пути к данным, `remote_servers`
  (кластер), настройки Keeper/ZooKeeper, логирование.
- `users.xml` — пользователи, пароли, квоты, профили настроек
  (ограничения на память/количество потоков на пользователя).
- `metrika.xml` (или просто вынесенные `<include>`) — часто сюда
  выносят `remote_servers`/`zookeeper`, чтобы не держать секреты и
  топологию кластера в основном конфиге.
Макросы (`<macros><shard>1</shard><replica>replica1</replica>
</macros>`) — именно они подставляются в `{shard}`/`{replica}` из
вопроса 3, и у каждого узла кластера свои значения.

# 5. Что такое словари (Dictionaries) в ClickHouse и зачем они
нужны?
Внешний справочник (например, таблица "страна → регион" из
Postgres/MySQL/файла), который ClickHouse подгружает в память и
кэширует с периодическим обновлением — используется функцией
`dictGet()` прямо в SQL-запросе вместо JOIN с медленной внешней
таблицей на каждый запрос.
```xml
<dictionary>
    <name>countries</name>
    <source><mysql><host>db1</host>...</mysql></source>
    <layout><hashed/></layout>
    <lifetime>300</lifetime>
</dictionary>
```
`lifetime` — как часто перечитывать источник (секунды).

# 6. Что такое TTL в ClickHouse и для чего его настраивают?
Правило, которое автоматически удаляет или перемещает старые данные
без ручных DELETE:
```sql
ALTER TABLE events MODIFY TTL ts + INTERVAL 30 DAY;
```
Через 30 дней после `ts` строки удалятся сами (фоновым merge).
Можно не удалять, а переносить на более дешевый диск:
`TTL ts + INTERVAL 7 DAY TO DISK 'cold_storage'`.

# 7. Какие кодеки сжатия чаще всего настраивают на колонках и
зачем?
```sql
CREATE TABLE events (
    ts DateTime CODEC(DoubleDelta, ZSTD),
    value Float64 CODEC(Gorilla, ZSTD)
) ENGINE = MergeTree ORDER BY ts;
```
По умолчанию колонки сжимаются LZ4 (быстро). `ZSTD` жмет сильнее,
но медленнее — используют для редко читаемых архивных данных.
`DoubleDelta`/`Gorilla` — специализированные кодеки для
монотонных/плавно меняющихся числовых рядов (временные метки,
метрики) перед общим сжатием — часто дают кратно лучший коэффициент,
чем просто ZSTD по сырым числам.

# 8. Как мониторить ClickHouse и что смотреть в первую очередь?
Встроенные системные таблицы вместо внешнего агента:
`system.query_log` (история запросов и их длительность),
`system.metrics`/`system.asynchronous_metrics` (текущее состояние
сервера), `system.parts` (сколько кусков данных у таблицы — если
их слишком много, merge не успевает). Для Prometheus используют
`clickhouse-exporter` либо встроенный `/metrics` эндпоинт
(`<prometheus>` секция в config.xml).

# 9. Как бэкапить ClickHouse?
Штатный способ — `clickhouse-backup` (отдельная утилита): делает
снэпшот данных таблицы с учетом партиций, умеет заливать в S3/GCS.
Более низкоуровневый вариант — `ALTER TABLE ... FREEZE` (создает
hard-link снэпшот партиций на диске мгновенно, без блокировки
записи), который потом архивируется обычными средствами ОС.
Просто скопировать директорию с данными "на горячую" без FREEZE
нельзя — файлы могут измениться в процессе копирования.
