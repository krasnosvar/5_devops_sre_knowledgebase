# Ответы: Loki и LogQL

Стенд поднят из `02_examples/` (`docker compose up -d`), Loki ответил
`ready` на `curl -s localhost:3100/ready`. LogQL-запросы выполняются в
Grafana → Explore (datasource Loki) или через `logcli`.

## Упражнение 01 — Базовые LogQL запросы

```logql
# 1. Все логи от log-generator
{service="log-generator"}

# 2. Только ответы 5xx — строковым фильтром
{service="log-generator"} |~ `"status":5\d\d`

# 3. JSON парсинг + фильтр по полю
{service="log-generator"} | json | status >= 500

# 4. Количество 5xx в минуту
count_over_time({service="log-generator"} |~ `"status":5\d\d` [1m])

# 5. Топ 5 сервисов по строкам со словом "error"
topk(5, sum by (service) (
  rate({service=~".+"} |= "error" [5m])
))
```

Ожидаемый вывод (примерно так):

```text
1. {"host":"73.216.148.30", ..., "method": "PUT", "status":201, ...}
2. {"host":"251.48.25.157", ..., "method": "PATCH", "status":500, ...}
3. те же строки, у каждой в Explore видны поля status=500, method=PATCH ...
4. {app="log-generator", service="log-generator", ...}  23
5. {service="grafana"}  0.023
   {service="loki"}     0.023
```

Почему так: метка `container` содержит имя вида
`02_examples-log-generator-1` (префикс проекта compose), поэтому стабильный
селектор — `service`, который Alloy берёт из docker-label
`com.docker.compose.service`. Селектор `{}` Loki отвергает — нужен хотя бы
один матчер, и `=~".+"` — канонический способ «все потоки». Строковый
фильтр (`|~`) дешевле `| json`: он не парсит строку целиком. flog не пишет
слово `error`, поэтому в п.5 попадают логи самих Loki/Grafana.

## Упражнение 02 — logcli из командной строки

Если бинарника нет, `logcli` можно запустить из образа (с хоста Loki
доступен на `localhost:3100`, поэтому `--network host`):

```bash
alias logcli='docker run --rm --network host -e LOKI_ADDR grafana/logcli:latest'
export LOKI_ADDR="http://localhost:3100"

logcli labels
logcli query --tail '{service="log-generator"}'
logcli query --quiet --since=30m --limit 50 \
  '{service="log-generator"} |~ `"status":5\d\d`'

# Метрика: сколько 5xx за последний час
logcli query --quiet --since=1h \
  'sum(count_over_time({service="log-generator"} |~ `"status":5\d\d` [1h]))'
```

Ожидаемый вывод (примерно так):

```text
app
container
env
service
service_name
2026-10-15T05:33:00Z {service="log-generator", ...} {"host":"...", "status":502, ...}
[ { "metric": {}, "value": [ 1792042448, "54" ] } ]
```

Почему так: `logcli` ходит в тот же HTTP API, что и Grafana
(`/loki/api/v1/query_range`, `/labels`). Метку `service_name` Loki 3.x
добавляет сам (копирует из `service`). `--quiet` убирает служебную
строку с URL запроса.

## Упражнение 03 — Push logs через API

```bash
NOW=$(date +%s%N)
curl -s -w '%{http_code}\n' -X POST "http://localhost:3100/loki/api/v1/push" \
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

logcli query --quiet --since=5m '{app="mytest"}'
```

Ожидаемый вывод (примерно так):

```text
204
2026-10-15T05:33:52Z {detected_level="error"} {"level": "error", "msg": "something failed"}
2026-10-15T05:33:52Z {detected_level="info"}  {"level": "info", "msg": "test message 1"}
```

Почему так: push API — это то, что делает любой агент (Alloy, Promtail,
OTel Collector): поток = набор меток + массив пар «время в наносекундах,
строка». `204 No Content` — успешный приём. `detected_level` Loki
вычисляет сам из содержимого строки.

## Упражнение 04 — Pipeline обработки в Alloy

Готовый блок — [alloy-pipeline.alloy](./alloy-pipeline.alloy): заменить
им `loki.process "containers"` в `02_examples/alloy-config.alloy`.

```bash
cd 02_examples/
docker compose restart alloy
sleep 30
curl -sG localhost:3100/loki/api/v1/label/status/values | jq -c '.data'
curl -sG localhost:3100/loki/api/v1/query --data-urlencode \
  'query=sum(count_over_time({service="log-generator", status="200"}[1m]))' \
  | jq '.data.result'
```

Ожидаемый вывод (примерно так):

```text
["100","201","204","301","302","304","400","401","403","404","500","502","503","504"]
[]
```

Почему так: `stage.match` ограничивает обработку одним сервисом — иначе
`stage.json` пытался бы парсить логи Loki/Grafana. `stage.drop` с `value`
сравнивает извлечённое поле точно, строки с 200 не доходят до Loki.
`status` как метка допустим, потому что кодов десятки; метка с
высокой кардинальностью (`request`, `host`) создала бы тысячи потоков —
такие поля фильтруют на запросе через `| json`.
