# Loki и LogQL: практика запросов и агентов

## Содержание
1. [Архитектура Loki](#1-архитектура-loki)
2. [Метки (Labels) — как правильно использовать](#2-метки-labels--как-правильно-использовать)
3. [LogQL — язык запросов](#3-logql--язык-запросов)
4. [Grafana Alloy — агент сбора логов](#4-grafana-alloy--агент-сбора-логов)
5. [Promtail — legacy-агент](#5-promtail--legacy-агент)
6. [Полезные запросы для DevOps](#6-полезные-запросы-для-devops)

---

## 1. Архитектура Loki

```
Приложение → Alloy / OTel Collector / (legacy: Promtail) → Loki
                                                            │
                                                  хранит индекс labels
                                                  + сжатые чанки логов
                                                            │
                                                  Grafana / logcli ← запросы
```

**Ключевое отличие от Elasticsearch**: Loki **не индексирует** содержимое логов,
только labels. Запросы grep по логам выполняются в runtime. Дешевле, но медленнее
для full-text search. Дешевле хранение, выше скорость ingestion.

## 2. Метки (Labels) — как правильно использовать

Labels — как в Prometheus. Каждая уникальная комбинация labels = отдельный stream.

**Хорошие labels** (малое количество уникальных значений):
- `env` = prod/staging/dev
- `app` = api/worker/frontend
- `namespace` (в k8s)
- `pod`

**Плохие labels** (высокая кардинальность):
- `user_id`, `request_id`, `trace_id` — создают миллионы streams → OOM Loki

Правило: labels должны быть для фильтрации streams, а не для поиска внутри.

## 3. LogQL — язык запросов

### 3.1 Stream selector (обязателен)

Селектор обязан содержать хотя бы один матчер, который не совпадает с
пустой строкой: `{}` и `{app=~".*"}` Loki отвергает. «Все потоки» —
`{app=~".+"}` (или любая метка, которая есть у всех потоков).

```logql
{app="nginx"}                              # логи nginx
{namespace="production", app="api"}        # несколько labels
{app=~"api|worker"}                        # regex
{app="api", env!="dev"}                    # исключить по второй метке
{app=~".+"}                                # все потоки, где есть app
```

### 3.2 Log pipeline — фильтрация и парсинг

```logql
# Фильтрация по тексту
{app="nginx"} |= "error"                  # содержит строку
{app="nginx"} |~ "5[0-9]{2}"             # regex
{app="nginx"} != "health"                  # не содержит
{app="nginx"} !~ "GET /api/health"        # не regex

# JSON парсинг
{app="api"} | json                         # парсить как JSON
{app="api"} | json | level="error"        # фильтр по JSON полю
{app="api"} | json | status >= 500        # числовое сравнение

# logfmt парсинг (key=value формат)
{app="worker"} | logfmt | duration > 1s   # медленные операции

# Regexp парсинг
{app="nginx"} | regexp `(?P<method>GET|POST|PUT|DELETE) (?P<path>/[^ ]*)`
             | method="POST"              # использовать извлечённое поле

# Паттерн парсинг (проще regexp для access logs)
{app="nginx"} | pattern `<ip> - <user> [<ts>] "<method> <path> <_>" <status> <size>`
             | status >= 500
```

### 3.3 Metric queries — из логов в метрики

```logql
# Количество error логов в минуту
count_over_time({app="api"} |= "error" [1m])

# Частота ошибок по сервису
sum by(app)(
  rate({namespace="production"} |= "error" [5m])
)

# Извлечь latency из лога и построить перцентиль
quantile_over_time(0.95,
  {app="api"} | json | unwrap duration_ms [5m]
) by (endpoint)

# Топ 5 медленных endpoint'ов
topk(5,
  avg_over_time({app="api"} | json | unwrap duration_ms [5m]) by (endpoint)
)
```

`unwrap` превращает значение поля в число сэмпла; дальше с ним работают
только `*_over_time` функции диапазона — обычный `avg by (...)` поверх
потока строк не применим.

## 4. Grafana Alloy — агент сбора логов

Alloy — основной агент Grafana для логов, метрик и трейсов (дистрибутив
OpenTelemetry Collector). Конфиг пишется на собственном языке Alloy
(раньше назывался River), файлы `*.alloy`. Конфиг — граф компонентов:
каждый блок экспортирует значения (`targets`, `receiver`), а другие
блоки на них ссылаются. Рабочий пример для Docker — в
[02_examples/alloy-config.alloy](../02_examples/alloy-config.alloy).

```alloy
// Логи подов k8s через Kubernetes API (без hostPath)
discovery.kubernetes "pods" {
  role = "pod"
}

discovery.relabel "pods" {
  targets = discovery.kubernetes.pods.targets

  rule {
    source_labels = ["__meta_kubernetes_namespace"]
    target_label  = "namespace"
  }

  rule {
    source_labels = ["__meta_kubernetes_pod_label_app"]
    target_label  = "app"
  }
}

loki.source.kubernetes "pods" {
  targets    = discovery.relabel.pods.output
  forward_to = [loki.process.pods.receiver]
}

loki.process "pods" {
  stage.json {
    expressions = { level = "level" }
  }

  stage.labels {
    values = { level = "" }
  }

  stage.drop {
    expression = ".*healthcheck.*"   // отбрасывать health check логи
  }

  forward_to = [loki.write.default.receiver]
}

loki.write "default" {
  endpoint {
    url = "http://loki:3100/loki/api/v1/push"
  }
}
```

Отладка: UI Alloy (`:12345`) показывает граф компонентов и состояние
каждого; `alloy fmt config.alloy` проверяет синтаксис.

## 5. Promtail — legacy-агент

Promtail снят с поддержки (сначала LTS, затем EOL): новых функций и
исправлений нет. Он ещё встречается в существующих инсталляциях, поэтому
его конфиг полезно уметь читать. Миграция:
`alloy convert --source-format=promtail --output=config.alloy
promtail-config.yaml`.

```yaml
# promtail-config.yaml (legacy)
server:
  http_listen_port: 9080

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  # Логи Docker контейнеров
  - job_name: docker
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
    relabel_configs:
      - source_labels: [__meta_docker_container_name]
        target_label: container
      - source_labels: [__meta_docker_container_label_com_docker_compose_service]
        target_label: app

  # Логи k8s через файлы
  - job_name: kubernetes-pods
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_namespace]
        target_label: namespace
      - source_labels: [__meta_kubernetes_pod_label_app]
        target_label: app
    pipeline_stages:
      - json:
          expressions:
            level: level
            msg: message
      - labels:
          level:
      - drop:
          expression: '.*healthcheck.*'   # отбрасывать health check логи

  # Системные логи
  - job_name: journal
    journal:
      path: /var/log/journal
      max_age: 12h
    relabel_configs:
      - source_labels: [__journal__systemd_unit]
        target_label: unit
```

## 6. Полезные запросы для DevOps

```logql
# Все ERROR логи в production, переформатированные в компактную строку
{namespace="production"} |= "ERROR" | json | line_format "{{.timestamp}} {{.service}}: {{.message}}"

# OOMKill события в k8s
{job="kubernetes-events"} |= "OOMKilled"

# Медленные SQL запросы
{app="postgres"} | regexp `duration: (?P<dur>[0-9.]+) ms` | dur > 1000

# Частота deploy'ев (из CI логов)
count_over_time({app="gitlab-runner"} |= "Job succeeded" [1d])

# 404 ошибки по path за 5 минут
sum by (path) (
  count_over_time({app="nginx"} | json | status="404" [5m])
)
```
