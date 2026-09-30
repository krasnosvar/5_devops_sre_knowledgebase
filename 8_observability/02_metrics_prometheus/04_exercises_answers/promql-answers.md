# Ответы: PromQL упражнения

## Упражнение 01 — Базовые запросы (выполнять в http://localhost:9090)

```promql
# 1. CPU usage % (среднее по всем ядрам)
100 - avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100

# 2. Memory available в GB
node_memory_MemAvailable_bytes / 1024^3

# 3. Disk usage / в %
(node_filesystem_size_bytes{mountpoint="/"} - node_filesystem_free_bytes{mountpoint="/"})
/ node_filesystem_size_bytes{mountpoint="/"} * 100

# 4. Network received MB/s
irate(node_network_receive_bytes_total{device!~"lo|veth.*|br.*|docker.*"}[5m]) / 1024^2

# 5. Топ-3 метрики по количеству time series
topk(3, count by (__name__)({__name__=~".+"}))
```

## Упражнение 02 — Alerting rules

```yaml
groups:
  - name: node-alerts
    rules:
      # CPU > 80% в течение 5 минут
      - alert: HighCPU
        expr: |
          100 - avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100 > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "CPU above 80%"
          description: "CPU is {{ $value | humanizePercentage }}"

      # Диск > 85%
      - alert: DiskAlmostFull
        expr: |
          (node_filesystem_size_bytes - node_filesystem_free_bytes)
          / node_filesystem_size_bytes * 100 > 85
        for: 10m
        labels:
          severity: warning

      # Сервис down (up == 0)
      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.job }} is down"
```

## Упражнение 03 — Recording rules

```yaml
groups:
  - name: recording
    rules:
      - record: job:node_cpu_usage:rate5m
        expr: |
          100 - avg by(instance)(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100

      - record: job:node_memory_usage_percent:current
        expr: |
          (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100
```

## Упражнение 04 — Burn rate (SLO 99.9%)

```promql
# Burn rate за последний час
(rate(http_requests_total{status=~"5.."}[1h])
 / rate(http_requests_total[1h]))
/ 0.001

# Alert: > 14.4x = бюджет сгорит за 2 дня
# > 14.4 * 0.001 = порог алерта
```
