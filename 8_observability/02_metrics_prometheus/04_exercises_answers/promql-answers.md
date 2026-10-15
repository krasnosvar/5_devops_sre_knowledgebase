# Ответы: Prometheus и PromQL

Стенд поднят из `02_examples/` (`docker compose up -d`). Запросы PromQL
выполняются в Expression Browser (http://localhost:9090) или через API:
`curl -sG localhost:9090/api/v1/query --data-urlencode 'query=<PromQL>'`.

## Упражнение 01 — Базовые PromQL запросы

```promql
# 1. Все метрики node_exporter: в Expression Browser начать вводить
#    node_ — автодополнение покажет список. Посчитать их количество:
count(count by (__name__) ({__name__=~"node_.+"}))

# 2. CPU usage в % (среднее по всем core)
100 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100

# 3. Доступная память в GB
node_memory_MemAvailable_bytes / 1024^3

# 4. Использование диска / в %
(node_filesystem_size_bytes{mountpoint="/"}
  - node_filesystem_avail_bytes{mountpoint="/"})
/ node_filesystem_size_bytes{mountpoint="/"} * 100

# 5. Топ-3 метрики по количеству time series
topk(3, count by (__name__) ({__name__=~".+"}))
```

Ожидаемый вывод (примерно так, значения зависят от хоста):

```text
1. {}  325
2. {}  12.4
3. {instance="node-exporter:9100", job="node-exporter"}  39.1
4. {device="/dev/...", fstype="ext4", mountpoint="/", ...}  64.9
5. {__name__="node_cpu_seconds_total"}            176
   {__name__="prometheus_http_requests_total"}    63
   {__name__="node_scrape_collector_duration_seconds"}  49
```

Почему так: CPU считается через долю времени в `idle` — `rate()` даёт
секунды простоя в секунду (0..1) на каждое ядро, `avg` усредняет по ядрам.
Для диска берётся `avail`, а не `free`: `free` включает блоки,
зарезервированные под root, и занижает реальное заполнение. Пока данных
меньше 5 минут, запрос с `[5m]` может вернуть пустой результат.

## Упражнение 02 — Alerting rules

Готовый файл — [node-alerts.yml](./node-alerts.yml).

```bash
cd 02_examples/
cp ../04_exercises_answers/node-alerts.yml alerts/node.yml
docker compose exec prometheus promtool check rules /etc/prometheus/alerts/node.yml
curl -X POST http://localhost:9090/-/reload
curl -s localhost:9090/api/v1/rules | jq -r '.data.groups[].rules[].name'
```

Ожидаемый вывод (примерно так):

```text
Checking /etc/prometheus/alerts/node.yml
  SUCCESS: 3 rules found

HighCPU
DiskAlmostFull
ServiceDown
```

Почему так: `for: 5m` превращает «CPU > 80%» в «держится 5 минут» —
алерт сначала висит в `pending`, и только потом `firing`. Значение
`$value` в HighCPU уже в процентах, поэтому в аннотации `printf`, а не
`humanizePercentage` (тот умножает на 100). Проверить ServiceDown:
`docker compose stop node-exporter` — через ~1 минуту алерт на
http://localhost:9090/alerts станет firing.

## Упражнение 03 — Recording rules

Готовый файл — [recording.yml](./recording.yml).

```bash
cp ../04_exercises_answers/recording.yml alerts/recording.yml
docker compose exec prometheus promtool check rules /etc/prometheus/alerts/recording.yml
curl -X POST http://localhost:9090/-/reload
# через 15-30 секунд:
curl -sG localhost:9090/api/v1/query \
  --data-urlencode 'query=job:node_cpu_usage:rate5m' | jq '.data.result'
```

Ожидаемый вывод (примерно так):

```text
  SUCCESS: 2 rules found
[
  {
    "metric": { "__name__": "job:node_cpu_usage:rate5m", "job": "node-exporter" },
    "value": [ 1791997007.7, "12.4" ]
  }
]
```

Почему так: имя `job:...` по конвенции `level:metric:operations` обещает
агрегацию до уровня job, поэтому `avg by (job)`. Recording rule
вычисляется каждые `evaluation_interval` и сохраняется как новая серия —
дашборды читают готовое значение, а не пересчитывают `rate` по сырым
данным.

## Упражнение 04 — Подключить своё приложение

Готовый сервер — [app.py](./app.py) (приложение на `:8001`, метрики на
`:8000/metrics`).

```bash
pip install prometheus_client
python app.py &
curl -s localhost:8001/ ; curl -s localhost:8001/error
curl -s localhost:8000/metrics | grep '^http_requests_total'
```

Добавить в `02_examples/prometheus.yml` в `scrape_configs`:

```yaml
  - job_name: 'myapp'
    static_configs:
      - targets: ['host.docker.internal:8000']
```

```bash
curl -X POST http://localhost:9090/-/reload
curl -sG localhost:9090/api/v1/query --data-urlencode 'query=up{job="myapp"}' \
  | jq -r '.data.result[].value[1]'
```

Ожидаемый вывод (примерно так):

```text
ok
error
http_requests_total{method="GET",path="/",status="200"} 1.0
http_requests_total{method="GET",path="/error",status="500"} 1.0
1
```

Дальше в Grafana (http://localhost:3000, admin/admin) → Dashboards → New
→ панель с запросом `sum by (status) (rate(http_requests_total[1m]))` и
вторая — `histogram_quantile(0.95, sum by (le)
(rate(http_request_duration_seconds_bucket[5m])))`.

Почему так: `start_http_server` поднимает отдельный HTTP-сервер для
`/metrics`, Prometheus сам приходит за метриками (pull). Имя
`host.docker.internal` резолвится в хост благодаря `extra_hosts:
host-gateway` в `docker-compose.yml`. Метка `path` здесь допустима только
потому, что путей два: на реальном сервисе с произвольными URL это
взрыв cardinality — используют шаблон маршрута.
