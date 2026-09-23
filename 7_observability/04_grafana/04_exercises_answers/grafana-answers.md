# Ответы: Grafana упражнения

## Упражнение 01 — Dashboard "Node Health"

PromQL для каждой панели:

```
CPU Usage %:
  100 - avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100
  Тип: Time series | Unit: percent | Thresholds: 70=yellow, 90=red

Memory Available GB:
  node_memory_MemAvailable_bytes / 1024^3
  Тип: Stat | Unit: decgbytes | Thresholds: 1=red, 4=green

Disk Usage %:
  (node_filesystem_size_bytes{mountpoint="/"} - node_filesystem_free_bytes{mountpoint="/"})
  / node_filesystem_size_bytes{mountpoint="/"} * 100
  Тип: Gauge | Min: 0 | Max: 100 | Thresholds: 75=yellow, 90=red

Network MB/s:
  irate(node_network_receive_bytes_total{device!~"lo"}[5m]) / 1024^2
  Тип: Time series | Unit: MBs
```

## Упражнение 02 — Template Variable

```
Settings → Variables → Add:
  Type: Query
  Name: instance
  Data source: Prometheus
  Query: label_values(node_uname_info, instance)
  Refresh: On Dashboard Load
  Include All: enabled

Использование в панелях:
  node_cpu_seconds_total{instance="$instance", mode="idle"}
```

## Упражнение 03 — Alert rule

```yaml
# В Alerting → Alert Rules → New:
Rule name: HighCPU
Evaluate every: 1m, for: 5m

Query A:
  Data source: Prometheus
  Expr: 100 - avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100

Condition:
  WHEN: last() of A
  IS ABOVE: 80

Labels:
  severity: warning

Annotations:
  summary: CPU is {{ $values.A.Value | printf "%.1f" }}%
```

## Упражнение 04 — Export/Import API

```bash
# Export
DASH_UID="node-health"
curl -s "http://admin:admin@localhost:3000/api/dashboards/uid/$DASH_UID" \
    | jq '.dashboard | del(.id, .version)' > node-health.json

# Import
curl -X POST "http://admin:admin@localhost:3000/api/dashboards/db" \
    -H "Content-Type: application/json" \
    -d "{\"dashboard\": $(cat node-health.json), \"overwrite\": true}"
```
