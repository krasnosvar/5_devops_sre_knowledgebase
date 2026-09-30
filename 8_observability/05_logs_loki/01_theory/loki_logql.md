# Loki и LogQL

## Архитектура Loki

```
Приложение → Promtail/Alloy/OTel Collector → Loki
                                               │
                                          хранит индекс labels
                                          + сжатые чанки логов
                                               │
                                          Grafana / logcli ← запросы
```

**Ключевое отличие от Elasticsearch**: Loki **не индексирует** содержимое логов,
только labels. Запросы grep по логам выполняются в runtime. Дешевле, но медленнее
для full-text search. Дешевле хранение, выше скорость ingestion.

## Метки (Labels) — как правильно использовать

Labels — как в Prometheus. Каждая уникальная комбинация labels = отдельный stream.

**Хорошие labels** (малое количество уникальных значений):
- `env` = prod/staging/dev
- `app` = api/worker/frontend
- `namespace` (в k8s)
- `pod`

**Плохие labels** (высокая кардинальность):
- `user_id`, `request_id`, `trace_id` — создают миллионы streams → OOM Loki

Правило: labels должны быть для фильтрации streams, а не для поиска внутри.

## LogQL — язык запросов

### Stream selector (обязателен)

```logql
{app="nginx"}                              # логи nginx
{namespace="production", app="api"}        # несколько labels
{app=~"api|worker"}                        # regex
{app!="nginx"}                             # исключить
```

### Log pipeline — фильтрация и парсинг

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

### Metric queries — из логов в метрики

```logql
# Количество error логов в минуту
count_over_time({app="api"} |= "error" [1m])

# Частота ошибок по сервису
sum by(app)(
  rate({namespace="production"} |= "error" [5m])
)

# Извлечь latency из лога и построить перцентиль
{app="api"} | json | unwrap duration_ms
  | quantile_over_time(0.95, [5m]) by (endpoint)

# Топ 5 медленных endpoint'ов
topk(5,
  avg by(endpoint)(
    {app="api"} | json | unwrap duration_ms [5m]
  )
)
```

## Promtail — агент сбора логов

```yaml
# promtail-config.yaml
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

## Grafana Alloy — замена Promtail (2024+)

```river
// alloy config.river
loki.source.kubernetes "pods" {
  targets    = discovery.kubernetes.pods.targets
  forward_to = [loki.write.default.receiver]
}

discovery.kubernetes "pods" {
  role = "pod"
}

loki.write "default" {
  endpoint {
    url = "http://loki:3100/loki/api/v1/push"
  }
}
```

## Полезные запросы для DevOps

```logql
# Все ERROR логи в production за последние 15 минут
{namespace="production"} |= "ERROR" | json | line_format "{{.timestamp}} {{.service}}: {{.message}}"

# OOMKill события в k8s
{job="kubernetes-events"} |= "OOMKilled"

# Медленные SQL запросы
{app="postgres"} | regexp `duration: (?P<dur>[0-9.]+) ms` | dur > 1000

# Частота deploy'ев (из CI логов)
count_over_time({app="gitlab-runner"} |= "Job succeeded" [1d])

# 404 ошибки по path
{app="nginx"} | json | status="404"
  | line_format "{{.path}}"
  | count_over_time([5m])
```
