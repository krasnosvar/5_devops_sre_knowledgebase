# Ответы — шаг 6 (Observability)

Задание — [README.md](README.md). Все команды — из папки `06_observability/`.

## 1. Target UP и трафик

```bash
docker compose up -d --build
curl -s 'http://localhost:9090/api/v1/query?query=up'
CODE=$(curl -s -X POST http://localhost:8000/shorten \
  -H 'content-type: application/json' \
  -d '{"url":"https://example.com"}' | jq -r .code)
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8000/$CODE
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8000/nope
```

Ожидаемый вывод (примерно так):

```text
{"status":"success","data":{"resultType":"vector","result":[{"metric":
{"__name__":"up","instance":"shortener:8000","job":"shortener"},
"value":[1791979130.025,"1"]}]}}
307
404
```

Почему так: `up` — синтетическая метрика самого Prometheus (1 = scrape
прошёл). `RedirectResponse` в FastAPI по умолчанию отдаёт 307.

## 2. PromQL

```text
sum by (endpoint) (rate(shortener_requests_total[5m]))

sum(rate(shortener_requests_total{endpoint="resolve",status="fail"}[5m]))
  / sum(rate(shortener_requests_total{endpoint="resolve"}[5m]))

histogram_quantile(0.95,
  sum by (le) (rate(shortener_request_duration_seconds_bucket{endpoint="shorten"}[5m])))
```

Почему так: `rate()` берут от counter до агрегации `sum`, иначе сброс
счётчика при рестарте даст скачок. Для квантиля по нескольким репликам
агрегируют бакеты с сохранением `le`, а не готовые квантили.

## 3. Правила

Решение — [answers/rules.yaml](answers/rules.yaml): две recording rules
(`shortener:requests:rate5m`, `shortener:request_duration_seconds:p95_5m`)
и алерты `ShortenerDown`, `ShortenerRedisUnavailable`,
`ShortenerHighLatencyP95`.

```bash
cp answers/rules.yaml rules.yaml
docker compose exec prometheus promtool check rules /etc/prometheus/rules.yaml
docker compose kill -s SIGHUP prometheus
curl -s http://localhost:9090/api/v1/rules | jq -r '.data.groups[].rules[].name'
```

Ожидаемый вывод (примерно так):

```text
Checking /etc/prometheus/rules.yaml
  SUCCESS: 5 rules found
shortener:requests:rate5m
shortener:request_duration_seconds:p95_5m
ShortenerDown
ShortenerRedisUnavailable
ShortenerHighLatencyP95
```

Почему так: SIGHUP заставляет Prometheus перечитать конфиг и правила без
потери данных. «Не видит Redis» ловится через `/health`: его каждые 10
секунд дёргает `HEALTHCHECK` из Dockerfile, и при недоступном Redis растёт
`shortener_requests_total{endpoint="health",status="fail"}`.

## 4. Дашборд Grafana

Datasource уже создан provisioning-ом. Dashboards → New → Add
visualization, три панели с запросами из п. 2 (или с recording rules
`shortener:requests:rate5m` и `shortener:request_duration_seconds:p95_5m`).
Сохранить дашборд и экспортировать JSON (Share → Export), чтобы хранить
его в git — подробнее в
[8_observability/08_dashboards_as_code](../../../8_observability/08_dashboards_as_code/).

## 5. Алерт при остановке Redis

```bash
docker compose stop redis
sleep 150
curl -s http://localhost:8000/health
curl -s http://localhost:9090/api/v1/alerts | jq -r '.data.alerts[] | "\(.labels.alertname) \(.state)"'
docker compose start redis
```

Ожидаемый вывод (примерно так):

```text
{"detail":"redis unavailable"}
ShortenerRedisUnavailable firing
```

Почему так: правило срабатывает, когда за 2 минуты был хотя бы один
неуспешный `/health`, и держится `for: 1m` — поэтому `firing` появляется
примерно через 1,5–2 минуты. `ShortenerDown` не срабатывает: процесс жив,
`/metrics` отдаётся.

## 6. Почему 500 на `/shorten` не видны в метриках

```bash
docker compose stop redis
curl -s -o /dev/null -w '%{http_code}\n' -X POST http://localhost:8000/shorten \
  -H 'content-type: application/json' -d '{"url":"https://x.org"}'
curl -s http://localhost:8000/metrics | grep 'shortener_requests_total{endpoint="shorten"'
docker compose start redis
```

Ожидаемый вывод (примерно так):

```text
500
shortener_requests_total{endpoint="shorten",status="ok"} 1.0
```

Почему так: `r.set()` бросает исключение `redis.ConnectionError`, и
функция выходит раньше строки `REQUESTS.labels(...).inc()`. Серия
`status="fail"` для `shorten` считает только 400 (нет `url`). Метрики
пишутся «руками» в успешных ветках кода — ошибки, которых автор не
предусмотрел, в них невидимы. Разбор и исправление — шаг 7.
