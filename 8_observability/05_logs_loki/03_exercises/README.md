# Упражнения — Loki и LogQL

Стенд: 🐳 Tier 1 — `8_observability/05_logs_loki/02_examples/`

```bash
cd ../02_examples/
docker compose up -d
curl -s localhost:3100/ready   # "ready" — Loki готов (через 15-30 с)
# Grafana с Loki datasource: http://localhost:3000
# Loki API: http://localhost:3100
# Alloy UI (граф компонентов сбора): http://localhost:12345
```

Агент сбора — Grafana Alloy (`alloy-config.alloy`): читает stdout всех
контейнеров хоста через Docker API и ставит метки `service` (имя сервиса
из compose), `container`, `app`, `env`. Генератор логов `log-generator`
(flog) пишет JSON access-log в stdout. Promtail оставлен как legacy
(`promtail-config.yaml`, профиль `promtail`) — он снят с поддержки.

> Alloy подхватывает и другие контейнеры хоста. Ошибки `timestamp too
> old` в `docker compose logs alloy` — это старые логи этих контейнеров,
> которые Loki отбрасывает (старше недели — лимит
> `reject_old_samples_max_age` по умолчанию); на лабу не влияют.

## 01 — Базовые LogQL запросы

Открыть Grafana → Explore → выбрать datasource Loki:

```logql
# 1. Все логи от log-generator
{service="log-generator"}

# 2. Только ответы 5xx — строковым фильтром (без парсинга)
{service="log-generator"} |~ `"status":5\d\d`

# 3. JSON парсинг и фильтр по полю
{service="log-generator"} | json | status >= 500

# 4. Количество 5xx логов за минуту
count_over_time({service="log-generator"} |~ `"status":5\d\d` [1m])

# 5. Топ 5 сервисов по количеству строк со словом "error"
#    (селектор обязан содержать хотя бы один матчер: {} недопустим)
topk(5, sum by (service) (
  rate({service=~".+"} |= "error" [5m])
))
```

## 02 — logcli из командной строки

```bash
# Установить logcli (бинарник с GitHub releases):
# https://github.com/grafana/loki/releases
# или без установки — образ grafana/logcli (см. ответы)

export LOKI_ADDR="http://localhost:3100"

# Список доступных labels
logcli labels

# Tail логов в реальном времени
logcli query --tail '{service="log-generator"}'

# Запрос за последний час
logcli query --since=1h --limit 100 '{service="log-generator"}'

# С фильтром
logcli query --since=30m '{service="log-generator"} |~ `"status":5\d\d`'
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

## 04 — Pipeline обработки в Alloy

**Задача:** добавить в блок `loki.process "containers"` в
`alloy-config.alloy` обработку, которая только для `log-generator`:
- парсит JSON-строку (поля `status`, `method`);
- отбрасывает строки со статусом 200;
- добавляет метку `status` из поля `status`.

Подсказка — нужные блоки: `stage.match` (ограничить селектором),
`stage.json`, `stage.drop`, `stage.labels`. После правки:
`docker compose restart alloy` и проверить, что
`{service="log-generator", status="200"}` пуст.

Для сравнения — то же самое в legacy-синтаксисе Promtail
(`pipeline_stages` в `promtail-config.yaml`):

```yaml
pipeline_stages:
  - match:
      selector: '{service="log-generator"}'
      stages:
        - json:
            expressions:
              status: status
              method: method
        - drop:
            source: status
            value: "200"
        - labels:
            status:
```
