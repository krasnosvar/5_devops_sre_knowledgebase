# Упражнения — Prometheus и PromQL

Стенд: 🐳 Tier 1 — Docker Compose

```bash
cd ../02_examples/
docker compose up -d
# Prometheus: http://localhost:9090
# Grafana: http://localhost:3000 (admin/admin)
# Node Exporter metrics: http://localhost:9100/metrics
```

## 01 — Базовые PromQL запросы

Выполнить в Prometheus Expression Browser (http://localhost:9090):

```promql
# TODO: написать запросы

# 1. Посмотреть все метрики node_exporter
# Подсказка: node_

# 2. CPU usage в % (среднее по всем core)
# Подсказка: irate(node_cpu_seconds_total{mode="idle"}[5m])

# 3. Доступная память в GB
# Подсказка: node_memory_MemAvailable_bytes

# 4. Использование диска / в %
# Подсказка: node_filesystem_size_bytes, node_filesystem_free_bytes

# 5. Топ-3 метрики по количеству time series
# Подсказка: topk(3, count by (__name__)({__name__=~".+"}))
```

## 02 — Alerting rules

**Задача:** Написать alerting rules для:
1. CPU > 80% в течение 5 минут
2. Диск > 85%
3. Сервис down (up == 0)

```bash
# Создать файл prometheus/alerts/node.yml
# Добавить в prometheus.yml: rule_files: ["alerts/*.yml"]
# Перезагрузить: curl -X POST http://localhost:9090/-/reload
# Проверить: http://localhost:9090/alerts
```

## 03 — Recording rules

**Задача:** Создать recording rules для частовычисляемых запросов:
1. `job:node_cpu_usage:rate5m` — CPU usage per job
2. `job:node_memory_usage_percent:current` — memory usage %

## 04 — Подключить своё приложение

**Задача:** Написать простой HTTP сервер (Python/Go) который экспортирует метрики в Prometheus формате. Добавить в scrape_configs. Создать дашборд в Grafana.

```python
# TODO: написать app.py с prometheus_client
from prometheus_client import Counter, Histogram, start_http_server
```
