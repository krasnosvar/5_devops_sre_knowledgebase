# VictoriaMetrics

## Почему VM вместо Prometheus

| | Prometheus | VictoriaMetrics |
|--|------------|-----------------|
| RAM на 1M series | ~5-6 GB | ~500 MB |
| Disk на 1 sample | ~1.5 bytes | ~0.4 bytes |
| Query speed | Baseline | 2-3× быстрее |
| Long-term storage | Нужен Thanos/Cortex | Встроено |
| Remote write | Endpoint есть | Принимает от Prometheus |
| PromQL совместимость | Эталон | Полная + MetricsQL |
| Clustering | Нет (federation) | Нативный кластер |

**Основной use case VM:** хранить больше метрик дольше на меньших ресурсах.

## Single-node — быстрый старт

```bash
# Docker
docker run -d --name victoriametrics \
  -p 8428:8428 \
  -v /path/to/vm-data:/victoria-metrics-data \
  victoriametrics/victoria-metrics:latest \
  -retentionPeriod=12    # хранить 12 месяцев
  -storageDataPath=/victoria-metrics-data

# HTTP API идентичен Prometheus
curl http://localhost:8428/api/v1/query?query=up
curl http://localhost:8428/metrics   # метрики самого VM
```

```yaml
# Prometheus remote_write → VictoriaMetrics
# prometheus.yml
remote_write:
  - url: http://victoriametrics:8428/api/v1/write
    queue_config:
      max_samples_per_send: 10000
      capacity: 100000
```

## Кластерный режим

```
vminsert  :8480   ← принимает writes (remote_write от Prometheus/Grafana Agent)
vmselect  :8481   ← выполняет queries (Grafana datasource)
vmstorage :8482   ← хранит данные (масштабируется горизонтально)
```

```yaml
# docker-compose для VM cluster
services:
  vmstorage-1:
    image: victoriametrics/vmstorage:latest
    command: -retentionPeriod=12 -storageDataPath=/storage
    volumes: [storage1:/storage]

  vmstorage-2:
    image: victoriametrics/vmstorage:latest
    command: -retentionPeriod=12 -storageDataPath=/storage
    volumes: [storage2:/storage]

  vminsert:
    image: victoriametrics/vminsert:latest
    command: -storageNode=vmstorage-1:8400,vmstorage-2:8400
    ports: ["8480:8480"]

  vmselect:
    image: victoriametrics/vmselect:latest
    command: -storageNode=vmstorage-1:8401,vmstorage-2:8401
    ports: ["8481:8481"]
```

## MetricsQL — расширения PoweQL

```promql
# Стандартный PromQL работает без изменений
rate(http_requests_total[5m])

# MetricsQL дополнения:

# default() — значение по умолчанию если нет данных
default(0, rate(http_requests_total[5m]))

# keep_last_value() — заполнить пробелы последним значением
keep_last_value(temperature{sensor="room1"})

# running_max() / running_min() — накопительный максимум
running_max(rate(errors_total[5m]))

# median() вместо avg()
median(cpu_usage{job="api"})

# outliers_iqr() — убрать выбросы (IQR метод)
outliers_iqr(response_time_seconds)

# aggr_over_time() — агрегация по времени
# аналог avg_over_time но поддерживает больше функций
aggr_over_time("percentile", 95, http_duration_seconds[1h])
```

## vmctl — миграция данных

```bash
# установить vmctl
curl -L https://github.com/VictoriaMetrics/VictoriaMetrics/releases/latest/download/vmutils-linux-amd64.tar.gz | tar xz

# Мигрировать данные из Prometheus в VM
./vmctl prometheus \
  --prom-snapshot-path=/var/lib/prometheus/snapshots/... \
  --vm-addr=http://victoriametrics:8428

# Создать snapshot в Prometheus для миграции
curl -XPOST http://prometheus:9090/api/v1/admin/tsdb/snapshot

# Мигрировать между двумя VM инстансами
./vmctl vm \
  --vm-addr=http://source-vm:8428 \
  --vm-native-dst-addr=http://dest-vm:8428 \
  --vm-native-filter-match='{job="kubernetes-pods"}' \
  --vm-native-filter-time-start=2024-01-01

# Мигрировать из InfluxDB в VM
./vmctl influx \
  --influx-addr=http://influxdb:8086 \
  --influx-database=mydb \
  --vm-addr=http://victoriametrics:8428
```

## vmalert — alerting

```yaml
# vmalert — выполняет alerting rules против VM
services:
  vmalert:
    image: victoriametrics/vmalert:latest
    command: >
      -datasource.url=http://victoriametrics:8428
      -remoteWrite.url=http://victoriametrics:8428/api/v1/write
      -notifier.url=http://alertmanager:9093
      -rule=/etc/alerts/*.yaml
    volumes:
      - ./alerts:/etc/alerts:ro
```

```yaml
# alerts/node.yaml — обычные Prometheus alerting rules работают без изменений
groups:
  - name: node
    rules:
      - alert: HighMemoryUsage
        expr: |
          (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) > 0.9
        for: 5m
        labels:
          severity: warning
```

## Grafana datasource

```yaml
# В Grafana: добавить как Prometheus datasource
# URL: http://victoriametrics:8428
# или для кластера: http://vmselect:8481/select/0/prometheus

# Тип datasource: Prometheus (не специальный VM тип)
# MetricsQL работает — Grafana воспринимает как PromQL
```
