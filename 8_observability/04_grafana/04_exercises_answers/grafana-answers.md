# Ответы: Grafana

Стенд — Prometheus + Grafana из
[02_metrics_prometheus/02_examples/](../../02_metrics_prometheus/02_examples/):
datasource `Prometheus` подключается автоматически через
`grafana-datasources.yaml`.

```bash
cd ../../02_metrics_prometheus/02_examples/
docker compose up -d
```

## Упражнение 01 — Первый дашборд вручную

В UI: Dashboards → New → New dashboard → Add visualization → datasource
Prometheus. Для каждой панели — запрос, тип и настройки:

```text
CPU Usage %:
  100 - avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100
  Тип: Time series | Unit: Percent (0-100)

Memory Available GB:
  node_memory_MemAvailable_bytes / 1024^3
  Тип: Stat | Unit: gigabytes | Decimals: 1

Disk Usage %:
  (node_filesystem_size_bytes{mountpoint="/"}
    - node_filesystem_avail_bytes{mountpoint="/"})
  / node_filesystem_size_bytes{mountpoint="/"} * 100
  Тип: Gauge | Min: 0 | Max: 100 | Thresholds: 80=yellow, 90=red

Network MB/s:
  irate(node_network_receive_bytes_total{device!~"lo"}[5m]) / 1024^2
  Тип: Time series | Unit: MiB/s
```

Сохранить дашборд с именем `Node Health`. Проверка, что он сохранён:

```bash
curl -s 'http://admin:admin@localhost:3000/api/search?query=Node%20Health' \
  | jq -r '.[].title'
```

Ожидаемый вывод (примерно так):

```text
Node Health
```

Почему так: для диска фильтр `mountpoint="/"` нужен, иначе Gauge получит
по серии на каждую ФС и покажет несколько стрелок. Unit задаётся в
панели, а не в запросе: Grafana сама форматирует проценты и байты.

## Упражнение 02 — Переменные (Template Variables)

```text
Dashboard Settings → Variables → Add variable:
  Type: Query
  Name: instance
  Data source: Prometheus
  Query: label_values(node_uname_info, instance)
  Refresh: On dashboard load

Использование в панелях:
  node_memory_MemAvailable_bytes{instance="$instance"}
  100 - avg(irate(node_cpu_seconds_total{instance="$instance", mode="idle"}[5m])) * 100
```

Проверить, какие значения увидит dropdown:

```bash
curl -sG localhost:9090/api/v1/label/instance/values \
  --data-urlencode 'match[]=node_uname_info' | jq -r '.data[]'
```

Ожидаемый вывод (примерно так):

```text
node-exporter:9100
```

Почему так: `label_values(metric, label)` выполняет тот же запрос к
Prometheus API. Если включить «Include All», в запросах нужен
`instance=~"$instance"` (регэксп), а не `=`, — иначе значение All не
совпадёт ни с одной серией.

## Упражнение 03 — Alert rule в Grafana

```text
Alerting → Alert rules → New alert rule:
  Rule name: HighCPU
  Query A (Prometheus):
    100 - avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100
  Expressions: Reduce (Last) of A → Threshold: IS ABOVE 80
  Folder / Evaluation group: любые, Evaluate every: 1m
  Pending period: 5m
  Labels: severity=warning
  Annotations: summary = CPU is {{ $values.A.Value | printf "%.1f" }}%
```

Проверить список правил через API:

```bash
curl -s http://admin:admin@localhost:3000/api/v1/provisioning/alert-rules \
  | jq -r '.[].title'
```

Ожидаемый вывод (примерно так):

```text
HighCPU
```

Почему так: «For: 5m» в Grafana называется pending period — правило
должно оставаться истинным 5 минут подряд. Grafana Alerting вычисляет
правило сама (запросом к datasource), в отличие от правил Prometheus,
которые вычисляет Prometheus и отправляет в Alertmanager.

## Упражнение 04 — Dashboard as Code

```bash
DASH_UID=$(curl -s 'http://admin:admin@localhost:3000/api/search?query=Node%20Health&type=dash-db' \
  | jq -r '.[0].uid')
echo "$DASH_UID"

curl -s "http://admin:admin@localhost:3000/api/dashboards/uid/$DASH_UID" \
  | jq '.dashboard | del(.id, .version)' > node-health-dashboard.json
jq -r '.title' node-health-dashboard.json

curl -s -X POST http://admin:admin@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d "{\"dashboard\": $(cat node-health-dashboard.json), \"overwrite\": true}" \
  | jq -r '.status'
```

Ожидаемый вывод (примерно так):

```text
abwxww
Node Health
success
```

Почему так: UID дашборда, созданного в UI, случайный — его находят через
`/api/search`. `id` и `version` удаляются, потому что это внутренние
поля конкретного инстанса Grafana; при импорте с ними возможен конфликт
версий. Повторный импорт с `overwrite: true` идемпотентен — это основа
подхода из [08_dashboards_as_code](../../08_dashboards_as_code/).
