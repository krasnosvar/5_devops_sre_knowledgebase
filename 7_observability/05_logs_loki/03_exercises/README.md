# Упражнения — Loki и LogQL

Стенд: 🐳 Tier 1 — `7_observability/05_logs_loki/02_examples/`

```bash
cd ../02_examples/
docker compose up -d
# Grafana с Loki datasource: http://localhost:3000
# Loki API: http://localhost:3100
```

## 01 — Базовые LogQL запросы

Открыть Grafana → Explore → выбрать datasource Loki:

```logql
# 1. Все логи от log-generator
{container="log-generator"}

# 2. Только логи с уровнем error
{container="log-generator"} |= "error"

# 3. JSON парсинг и фильтр по полю
{container="log-generator"} | json | status >= 500

# 4. Количество ERROR логов за минуту
count_over_time({container="log-generator"} |= "error" [1m])

# 5. Топ 5 контейнеров по количеству error логов
topk(5, sum by(container)(
  rate({} |= "error" [5m])
))
```

## 02 — logcli из командной строки

```bash
# Установить logcli (скачать с GitHub releases)
# https://github.com/grafana/loki/releases

export LOKI_ADDR="http://localhost:3100"

# Список доступных labels
logcli labels

# Tail логов в реальном времени
logcli query --tail '{container="log-generator"}'

# Запрос за последний час
logcli query --since=1h '{container="log-generator"}' --limit 100

# С фильтром
logcli query '{container="log-generator"} |= "error"' --since=30m
```

## 03 — Push logs через API

```bash
# Отправить тестовые логи в Loki через curl
NOW=$(date +%s%N)
curl -s -X POST "http://localhost:3100/loki/api/v1/push" \
  -H "Content-Type: application/json" \
  -d "{
    \"streams\": [{
      \"stream\": {\"app\": \"mytest\", \"env\": \"lab\"},
      \"values\": [
        [\"$NOW\", \"{\\\"level\\\": \\\"info\\\", \\\"msg\\\": \\\"test message 1\\\"}\"],
        [\"$(($NOW + 1000000))\", \"{\\\"level\\\": \\\"error\\\", \\\"msg\\\": \\\"something failed\\\"}\"]
      ]
    }]
  }"

# Проверить в Grafana/Explore:
# {app="mytest"}
```

## 04 — Написать Promtail pipeline

**Задача:** Добавить в `promtail-config.yaml` pipeline stage которая:
- Парсит JSON логи от log-generator
- Добавляет label `level` из поля `status` лога
- Отбрасывает логи со статусом 200

```yaml
pipeline_stages:
  - json:
      expressions:
        status: status
        method: method
  - labels:
      status:
  - drop:
      source: status
      expression: "200"
```
