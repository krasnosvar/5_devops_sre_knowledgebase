# Ответы: Loki / LogQL упражнения

## Упражнение 01 — Базовые LogQL запросы

```logql
# 1. Все логи от log-generator
{container="log-generator"}

# 2. Только error
{container="log-generator"} |= "error"

# 3. JSON парсинг + filter по полю
{container="log-generator"} | json | status >= 500

# 4. Количество ERROR в минуту
count_over_time({container="log-generator"} |= "error" [1m])

# 5. Топ 5 по ошибкам
topk(5, sum by(container)(
  rate({} |= "error" [5m])
))
```

## Упражнение 02 — logcli

```bash
export LOKI_ADDR="http://localhost:3100"

# Список labels
logcli labels

# Tail в реальном времени
logcli query --tail '{container="log-generator"}'

# За последние 30 минут с фильтром
logcli query --since=30m '{container="log-generator"} |= "error"' --limit 50

# Статистика: количество ошибок
logcli query 'count_over_time({container="log-generator"} |= "error" [1h])'
```

## Упражнение 03 — Push logs через API

```bash
NOW=$(date +%s%N)
curl -s -X POST "http://localhost:3100/loki/api/v1/push" \
  -H "Content-Type: application/json" \
  -d "{
    \"streams\": [{
      \"stream\": {\"app\": \"mytest\", \"level\": \"info\"},
      \"values\": [
        [\"$NOW\", \"{\\\"level\\\": \\\"info\\\", \\\"msg\\\": \\\"test message\\\"}\"],
        [\"$(($NOW + 1000000))\", \"{\\\"level\\\": \\\"error\\\", \\\"msg\\\": \\\"test error\\\"}\"]
      ]
    }]
  }"

# Проверить:
logcli query --since=1m '{app="mytest"}'
```

## Упражнение 04 — Promtail pipeline

```yaml
# Добавить в promtail-config.yaml в job log-generator:
pipeline_stages:
  - json:
      expressions:
        status: status
        method: method
        path: path
  - labels:
      status:       # добавить label из JSON поля
  - drop:
      source: status
      expression: "200"   # не хранить 200-е ответы
  - output:
      source: path  # использовать path как итоговый лог-message
```
