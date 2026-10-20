# Observability на масштабе — шпаргалка

Подробности и объяснения — в
[observability_at_scale.md](./01_theory/observability_at_scale.md).
⚠️ — опасная команда или частая ловушка.

## Когда что использовать

| Ситуация | Выбор |
| :--- | :--- |
| Пара кластеров, нужны только агрегаты наверху | Federation (`/federate`) recording rules |
| Десятки кластеров, история и глобальные запросы | локальный Prometheus/vmagent + `remote_write` в центр |
| Уже много Prometheus, нужен общий query + S3 без переделки | Thanos (Sidecar, Store Gateway, Querier, Compactor) |
| Центральное мультитенантное хранилище, S3 | Grafana Mimir (или Cortex) |
| Минимум компонентов и RAM | VictoriaMetrics cluster |
| Логи: дорого хранить всё | sampling шума + tiered retention |

| | Thanos | Mimir | VictoriaMetrics cluster |
| :--- | :--- | :--- | :--- |
| Приём | Sidecar (блоки в S3) или Receive (`remote_write`) | `remote_write` → distributor | `remote_write` → vminsert |
| Хранение | объектное (S3/GCS) | объектное (S3/GCS) | локальные диски vmstorage |
| Дедуп HA-пары | Querier, `--query.replica-label` | HA tracker (`cluster`/`__replica__`) | `-dedup.minScrapeInterval` |
| Мультитенантность | через Receive/tenant header | `X-Scope-OrgID` | `accountID` в URL |

## Найти cardinality

| Задача | Команда / запрос |
| :--- | :--- |
| Всего активных рядов | `prometheus_tsdb_head_series` |
| Топ метрик по числу рядов ⚠️ тяжёлый | `topk(10, count by (__name__) ({__name__=~".+"}))` |
| Топ лейблов у метрики | `count by (path) (http_requests_total)` → сколько значений |
| Статистика head-блока | `curl -s localhost:9090/api/v1/status/tsdb \| jq '.data.seriesCountByMetricName[:10]'` |
| Анализ блоков на диске | `promtool tsdb analyze /prometheus` |
| Churn (рост новых рядов) | `rate(prometheus_tsdb_head_series_created_total[5m])` |
| Сколько рядов отдаёт target | `scrape_series_added`, `scrape_samples_scraped` |
| VictoriaMetrics | `/api/v1/status/tsdb`, VMUI → Cardinality explorer |

## Резать на источнике

```yaml
scrape_configs:
  - job_name: app
    sample_limit: 50000          # target отдаёт больше — scrape провален
    label_limit: 30
    static_configs:
      - targets: ['app:8080']
    metric_relabel_configs:      # после scrape, до записи в TSDB
      - action: labeldrop        # выкинуть лейбл целиком
        regex: (user_id|session_id|request_id)
      - action: drop             # выкинуть метрику
        source_labels: [__name__]
        regex: go_gc_.*|debug_.*
      - action: replace          # /users/12345 → /users/:id
        source_labels: [path]
        regex: /users/[0-9]+
        target_label: path
        replacement: /users/:id
```

⚠️ `labeldrop` может склеить ряды в дубликаты — убирать только лейблы,
не нужные для уникальности. Исправлять всё равно в коде приложения.

## remote_write и federation

```yaml
remote_write:
  - url: http://vminsert:8480/insert/1/prometheus/api/v1/write
    queue_config:
      capacity: 10000
      max_shards: 50
      max_samples_per_send: 2000
    write_relabel_configs:       # в центр — только агрегаты
      - action: keep
        source_labels: [__name__]
        regex: 'job:.*|up'

global:
  external_labels:               # обязательно: кто прислал
    cluster: prod-eu-1
    replica: a
```

```yaml
# верхний Prometheus: federation
scrape_configs:
  - job_name: federate
    honor_labels: true
    metrics_path: /federate
    params:
      'match[]': ['{__name__=~"job:.*"}']
    static_configs:
      - targets: ['prom-eu:9090', 'prom-us:9090']
```

## Лимиты как предохранитель

| Система | Лимит |
| :--- | :--- |
| Prometheus | `sample_limit`, `label_limit`, `label_value_length_limit` на scrape job |
| VictoriaMetrics | `-storage.maxHourlySeries`, `-storage.maxDailySeries` |
| Mimir | `max_global_series_per_user`, `ingestion_rate` на tenant |
| Loki | `max_global_streams_per_user`, `ingestion_rate_mb`, `max_label_names_per_series` |

## Логи на масштабе

| Приём | Как |
| :--- | :--- |
| Biased sampling | ошибки — 100%, успешные/debug — 1–10% (на агенте: `stage.sampling` в Alloy) |
| Отбрасывать шум на агенте | `stage.drop` для health-check, debug в prod |
| Tiered retention | горячее (дни, быстро) + архив в S3 (месяцы, медленно) |
| Разный срок по потокам (Loki) | `retention_stream` в `limits_config` (нужен compactor с `retention_enabled: true`) |
| Структурированные логи | JSON на источнике — дешёвый `\| json` вместо regex по тексту |

## Алертинг поверх многих кластеров

| Правило | Почему |
| :--- | :--- |
| Локальные алерты считаются локально | центр упал — локальные алерты живы |
| Глобальные SLO — в центре | агрегат флота |
| Плюс пороги `by (cluster)` | ⚠️ один больной кластер тонет в среднем по 100 |
| `external_labels` с `cluster` везде | иначе ряды разных кластеров смешаются |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| Prometheus OOM после релиза | `/api/v1/status/tsdb`, новый лейбл в метрике релиза |
| `remote_write` отстаёт | `prometheus_remote_storage_highest_timestamp_in_seconds` vs `prometheus_remote_storage_queue_highest_sent_timestamp_seconds`, shards, сеть |
| Дубли/ступеньки в глобальном виде | нет дедупа реплик, одинаковые `external_labels` у разных кластеров |
| Federation таймаутит | тянут сырые ряды: только recording rules в `match[]` |
| Центр лёг — команды ослепли | нет локального Prometheus/Grafana в кластере |

> Проверка: scrape/relabel/remote_write/federation-конфиги прошли
> `promtool check config` (prom/prometheus:v3.5.0); не проверено:
> лимиты Mimir/Loki и `stage.sampling` — по документации, без запуска.
