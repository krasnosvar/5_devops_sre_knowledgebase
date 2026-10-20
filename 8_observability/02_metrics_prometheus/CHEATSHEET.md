# Prometheus и PromQL — шпаргалка

Подробности и объяснения — в [01_theory/](./01_theory/). ⚠️ — опасная
команда или частая ловушка.

## Типы метрик

Подробно: [01_prometheus.md](./01_theory/01_prometheus.md).

| Тип | Поведение | Чем читать | Пример |
| :--- | :--- | :--- | :--- |
| Counter | только растёт, сброс в 0 при рестарте | `rate()`, `increase()` | `http_requests_total` |
| Gauge | вверх и вниз | как есть, `*_over_time()`, `deriv()` | `node_memory_MemAvailable_bytes` |
| Histogram | `_bucket{le=...}`, `_sum`, `_count` | `histogram_quantile()` по `rate(_bucket)` | `http_request_duration_seconds` |
| Summary | квантили считает клиент | читать как есть | ⚠️ нельзя агрегировать между инстансами |

| Соглашение | Пример |
| :--- | :--- |
| Суффикс единиц (секунды, байты) | `_seconds`, `_bytes` |
| Counter оканчивается на `_total` | `http_requests_total` |
| Recording rule: `level:metric:operations` | `job:http_requests_total:rate5m` |

## Селекторы

Подробно: [02_promql.md](./01_theory/02_promql.md).

| Задача | Запрос |
| :--- | :--- |
| Точное совпадение | `http_requests_total{job="api", status="200"}` |
| Регулярка / отрицание | `{status=~"5.."}` / `{status!~"5.."}` / `{mode!="idle"}` |
| Исключить интерфейсы | `{device!~"lo\|veth.*\|docker.*"}` |
| Range vector за 5 мин | `http_requests_total[5m]` |
| Значение час назад | `http_requests_total offset 1h` |
| Мультизначная переменная Grafana | `{namespace=~"$namespace"}` (не `=`) |

## Функции и агрегации

| Задача | Запрос |
| :--- | :--- |
| RPS (сглаженно, для алертов) | `rate(http_requests_total[5m])` |
| Мгновенная скорость (дебаг, не для алертов) ⚠️ | `irate(http_requests_total[5m])` |
| Прирост за час | `increase(http_requests_total[1h])` |
| Сумма по метке / без метки | `sum by (job) (...)` / `sum without (instance) (...)` |
| Топ-5 | `topk(5, sum by (pod) (rate(...[5m])))` |
| Перцентиль p95 | `histogram_quantile(0.95, sum by (le, job) (rate(x_bucket[5m])))` |
| Среднее из гистограммы | `rate(x_sum[5m]) / rate(x_count[5m])` |
| Ряд пропал (target исчез) | `absent(up{job="api"})` |
| Диск кончится через 4 ч | `predict_linear(node_filesystem_avail_bytes[6h], 4*3600) < 0` |
| Переименовать метку | `label_replace(m, "dst", "$1", "src", "(.*)")` |
| Сравнить с неделей назад | `rate(x[5m]) / rate(x[5m] offset 1w)` |

⚠️ `histogram_quantile` без `le` в `by` вернёт пусто; `rate()`
применяют до `sum()`, не наоборот; окно `rate` ≥ 4× scrape interval.

## Готовые запросы

| Что | Запрос |
| :--- | :--- |
| CPU %, node_exporter | `100 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100` |
| Доступная память % | `node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100` |
| Диск занят % | `(1 - node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100` |
| Error rate % | `sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100` |
| Рестарты контейнеров | `increase(kube_pod_container_status_restarts_total[15m]) > 0` |
| Поды не Running | `kube_pod_status_phase{phase!~"Running\|Succeeded"} > 0` |
| CPU пода % от лимита | `sum by (namespace, pod, container) (rate(container_cpu_usage_seconds_total[5m])) / sum by (namespace, pod, container) (kube_pod_container_resource_limits{resource="cpu"}) * 100` |
| Target недоступен | `up == 0` |

## Правила

```yaml
groups:
  - name: api.rules
    rules:
      - record: job:http_requests_total:rate5m
        expr: sum by (job) (rate(http_requests_total[5m]))
      - alert: HighErrorRate
        expr: |
          sum by (job) (rate(http_requests_total{status=~"5.."}[5m]))
            / sum by (job) (rate(http_requests_total[5m])) > 0.001
        for: 5m            # Inactive → Pending → Firing
        labels:
          severity: warning
        annotations:
          summary: "Error rate {{ $value | humanizePercentage }} on {{ $labels.job }}"
          runbook_url: "https://wiki/runbooks/high-error-rate"
```

## promtool и API

| Задача | Команда |
| :--- | :--- |
| Проверить конфиг (и rule_files) | `promtool check config prometheus.yml` |
| Проверить файл правил | `promtool check rules alerts/*.yml` |
| Unit-тесты правил | `promtool test rules tests.yml` |
| Проверить формат `/metrics` | `curl -s localhost:8080/metrics \| promtool check metrics` |
| Запрос из консоли | `promtool query instant http://localhost:9090 'up'` |
| Топ кардинальности в TSDB | `promtool tsdb analyze /prometheus` |
| Перечитать конфиг (нужен `--web.enable-lifecycle`) | `curl -X POST localhost:9090/-/reload` (или `kill -HUP <pid>`) |
| Состояние targets | `curl -s localhost:9090/api/v1/targets \| jq '.data.activeTargets[] \| {job: .labels.job, health}'` |
| Мгновенный запрос через API | `curl -sG localhost:9090/api/v1/query --data-urlencode 'query=up'` |
| Метрики с наибольшим числом рядов | `topk(10, count by (__name__) ({__name__=~".+"}))` ⚠️ тяжёлый |

Тест правил (`promtool test rules tests.yml`):

```yaml
rule_files: [rules.yml]
evaluation_interval: 1m
tests:
  - interval: 1m
    input_series:
      - series: 'http_requests_total{job="api",status="500"}'
        values: '0+10x10'
      - series: 'http_requests_total{job="api",status="200"}'
        values: '0+100x10'
    alert_rule_test:
      - eval_time: 10m
        alertname: HighErrorRate
        exp_alerts:
          - exp_labels: {severity: warning, job: api}
            exp_annotations:   # ⚠️ сравниваются целиком
              summary: "Error rate 9.091% on api"
              runbook_url: "https://wiki/runbooks/high-error-rate"
```

## Конфиг и дефолты

| Параметр | Значение |
| :--- | :--- |
| `scrape_interval` / `evaluation_interval` | дефолт 1m; на практике 15s–30s |
| `scrape_timeout` | дефолт 10s, ≤ `scrape_interval` |
| Retention | `--storage.tsdb.retention.time=15d` (дефолт 15d), `...retention.size` |
| Порты | Prometheus 9090, Alertmanager 9093, node_exporter 9100, Pushgateway 9091 |
| k8s без оператора | аннотация `prometheus.io/scrape: "true"` + relabel `keep` |
| k8s с Prometheus Operator | CRD `ServiceMonitor` / `PodMonitor` / `PrometheusRule` |
| Короткоживущие job'ы | Pushgateway (⚠️ только для batch, не для сервисов) |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| Prometheus OOM / растёт RAM | `prometheus_tsdb_head_series`, `promtool tsdb analyze`, лейблы с ID |
| Target `DOWN` | `/targets` (ошибка scrape), сеть/порт, `scrape_timeout` |
| Правило не срабатывает | `/rules` (health, last error), `/alerts` (Pending?), `for:` |
| Нет данных у `rate()` | окно меньше 2 scrape-интервалов |
| Ступеньки после рестарта | норма: `rate()` учитывает counter reset |
| Ряды «висят» после деплоя | churn: stale-ряды старых подов в head-блоке |

> Проверка: все запросы из таблиц прошли парсинг в запущенном
> Prometheus (prom/prometheus:v3.5.0); правила и тест —
> `promtool check rules` / `promtool test rules`; `promtool query`,
> `check metrics`, `/-/reload`, `/api/v1/targets`, `/api/v1/status/tsdb` —
> выполнены; не проверено: `promtool tsdb analyze` на реальных блоках.
