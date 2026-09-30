# Упражнения — Grafana

Стенд: 🐳 Tier 1 — Prometheus + Grafana из `7_observability/02_metrics_prometheus/02_examples/`

## 01 — Первый дашборд вручную

**Задача:** Создать дашборд "Node Health" с 4 панелями.

```
1. CPU Usage (%) — Graph
   PromQL: 100 - avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100

2. Memory Available (GB) — Stat
   PromQL: node_memory_MemAvailable_bytes / 1024^3

3. Disk Usage (%) — Gauge (threshold: 80% = yellow, 90% = red)
   PromQL: (node_filesystem_size_bytes - node_filesystem_free_bytes)
           / node_filesystem_size_bytes * 100

4. Network Traffic (MB/s) — Graph
   PromQL: irate(node_network_receive_bytes_total{device!~"lo"}[5m]) / 1024^2
```

## 02 — Переменные (Template Variables)

**Задача:** Добавить в дашборд переменную `$instance` которая позволяет
выбирать конкретный хост из dropdown.

```
Dashboard Settings → Variables → Add variable
  Type: Query
  Name: instance
  Data source: Prometheus
  Query: label_values(node_uname_info, instance)
  Refresh: On Dashboard Load

Использовать в панелях:
  node_memory_MemAvailable_bytes{instance="$instance"}
```

## 03 — Alert rule в Grafana

**Задача:** Создать alert "High CPU" который срабатывает при CPU > 80% в течение 5 минут.

```
Panel → Edit → Alert tab → New alert rule
  Condition: avg() of cpu_usage > 80
  For: 5m
  Labels: severity=warning
  Annotations: summary="CPU above 80%"
```

Проверить что алерт отображается в Alerting → Alert Rules.

## 04 — Dashboard as Code

**Задача:** Экспортировать дашборд из упражнения 01 в JSON и
закоммитить в репозиторий.

```bash
# Экспорт через API
curl -s http://admin:admin@localhost:3000/api/dashboards/uid/node-health \
  | jq '.dashboard | del(.id, .version)' > node-health-dashboard.json

# Проверить что JSON корректен
cat node-health-dashboard.json | jq '.title'

# Импортировать обратно (тест idempotency)
curl -X POST http://admin:admin@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d "{\"dashboard\": $(cat node-health-dashboard.json), \"overwrite\": true}"
```
