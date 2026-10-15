# PromQL — язык запросов Prometheus

## Типы метрик

**Counter** — монотонно растёт, никогда не убывает. Для: запросы, байты, ошибки.
```promql
http_requests_total{job="api"}   # текущее значение (мало полезно само по себе)
rate(http_requests_total[5m])    # скорость в секунду за последние 5 минут
increase(http_requests_total[1h])  # прирост за последний час
```

**Gauge** — может расти и убывать. Для: память, температура, активные соединения.
```promql
node_memory_MemAvailable_bytes    # текущее значение (уже полезно)
```

**Histogram** — распределение значений по bucket'ам. Для: latency, размер запросов.
```promql
http_request_duration_seconds_bucket{le="0.5"}   # запросы быстрее 0.5с
http_request_duration_seconds_sum                # сумма всех latency
http_request_duration_seconds_count              # количество запросов

# перцентиль latency
histogram_quantile(0.95,
  sum by(le, job)(rate(http_request_duration_seconds_bucket[5m]))
)
```

**Summary** — предвычисленные квантили на стороне клиента (нельзя агрегировать между инстансами).

## Операторы и функции

```promql
# Агрегация
sum(metric)                    # сумма по всем time series
sum by(job)(metric)            # сумма, сгруппированная по label "job"
sum without(instance)(metric)  # сумма, убрать label "instance"
avg, min, max, count, stddev, topk, bottomk

# rate и increase — для counters
rate(http_requests_total[5m])     # скорость за 5 минут
irate(http_requests_total[2m])    # мгновенная скорость (последние 2 точки)
increase(http_requests_total[1h]) # абсолютный прирост за 1 час

# Math
http_errors_total / http_requests_total                    # доля ошибок
(1 - (free / total)) * 100                                # % использования
abs(), ceil(), floor(), round(), sqrt(), exp(), ln()

# Time functions
time()                        # текущее время в Unix timestamp
timestamp(metric)             # timestamp последнего сэмпла

# Label manipulation
label_replace(metric, "dst_label", "$1", "src_label", "(.*)")
```

## Практические запросы

```promql
# CPU использование (node_exporter)
100 - avg by(instance)(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100

# Память доступная в %
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100

# Использование диска
(node_filesystem_size_bytes - node_filesystem_free_bytes) /
  node_filesystem_size_bytes * 100

# Сетевой трафик (байт/сек)
irate(node_network_receive_bytes_total{device!~"lo|veth.*|br.*|docker.*"}[5m])

# HTTP error rate (%)
rate(http_requests_total{status=~"5.."}[5m])
  / rate(http_requests_total[5m]) * 100

# 95-й перцентиль latency по сервисам
histogram_quantile(0.95,
  sum by(le, service)(rate(http_request_duration_seconds_bucket[5m]))
)

# k8s: рестарты контейнеров за 15 минут
increase(kube_pod_container_status_restarts_total[15m]) > 0

# k8s: поды не в Running состоянии
kube_pod_status_phase{phase!="Running",phase!="Succeeded"} > 0

# k8s: использование CPU в % от лимита
100 * sum by(pod, container, namespace)(
  rate(container_cpu_usage_seconds_total[5m])
) / sum by(pod, container, namespace)(
  kube_pod_container_resource_limits{resource="cpu"}
)
```

## Alerting rules

```yaml
# prometheus_rules.yml
groups:
  - name: slo.rules
    interval: 1m
    rules:
      # SLO: error rate не более 0.1%
      - alert: HighErrorRate
        expr: |
          (
            rate(http_requests_total{status=~"5.."}[5m])
            / rate(http_requests_total[5m])
          ) > 0.001
        for: 5m          # держаться 5 минут прежде чем алертить
        labels:
          severity: warning
        annotations:
          summary: "High error rate on {{ $labels.service }}"
          description: "Error rate is {{ $value | humanizePercentage }}"
          runbook: "https://wiki/runbooks/high-error-rate"

      # Burn rate алерт (14.4x за 1 час = потратим бюджет за 2 дня)
      - alert: ErrorBudgetBurnRateFast
        expr: |
          (
            rate(http_requests_total{status=~"5.."}[1h])
            / rate(http_requests_total[1h])
          ) > (14.4 * 0.001)
        for: 2m
        labels:
          severity: critical

  - name: recording.rules
    rules:
      # Recording rule: предвычислять тяжёлый запрос
      - record: job:http_requests_total:rate5m
        expr: sum by(job)(rate(http_requests_total[5m]))

      - record: job:http_errors_total:rate5m
        expr: sum by(job)(rate(http_requests_total{status=~"5.."}[5m]))
```

## Selectors — фильтрация по labels

```promql
# Точное совпадение
http_requests_total{job="api", status="200"}

# Регулярное выражение
http_requests_total{status=~"2.."}        # все 2xx
http_requests_total{status!~"5.."}        # всё кроме 5xx
node_cpu_seconds_total{mode!="idle"}      # все режимы кроме idle

# Исключить
node_network_receive_bytes_total{device!~"lo|veth.*|docker.*"}

# Временной диапазон
http_requests_total[5m]     # последние 5 минут (range vector)
http_requests_total offset 1h  # значение 1 час назад
```
