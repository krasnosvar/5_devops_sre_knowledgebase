# Ответы: Distributed Tracing

Стенд поднят из `02_examples/` (`docker compose up -d`): OTel Collector,
Jaeger v2 и демо-приложение HotROD.

## Упражнение 01 — Explore traces в Jaeger UI

Сгенерировать несколько traces можно и без браузера — это тот же запрос,
что отправляет кнопка в UI HotROD:

```bash
for c in 123 392 731; do curl -s "http://localhost:8080/dispatch?customer=$c"; echo; done
```

Ожидаемый вывод (примерно так):

```text
{"Driver":"T747138C","ETA":120000000000}
...
```

Ответы на вопросы (по trace операции `GET /dispatch` сервиса frontend):
- Сервисов в одном запросе — 6: `frontend`, `customer`, `mysql`,
  `driver`, `redis-manual`, `route`.
- Самый долгий span — обычно запрос `customer` → `mysql` (SQL SELECT,
  ~300 мс и больше): HotROD специально имитирует медленную БД и
  блокировку на ней при параллельных запросах.
- Spans с ошибками — у `redis-manual`: HotROD случайно генерирует
  таймауты Redis, такие spans помечены красным (status = error).

Почему так: Gantt-диаграмма trace показывает и последовательные вызовы
(`customer` перед `driver`), и параллельные (пачка вызовов `route`
одновременно) — это главная ценность трейсинга по сравнению с логами.

## Упражнение 02 — Jaeger API

```bash
JAEGER="http://localhost:16686"
START=$(date -u -d '-1 hour' +%Y-%m-%dT%H:%M:%SZ)
END=$(date -u +%Y-%m-%dT%H:%M:%SZ)

curl -s "$JAEGER/api/v3/services" | jq -r '.services[]'

curl -sG "$JAEGER/api/v3/traces" \
  --data-urlencode query.service_name=frontend \
  --data-urlencode query.start_time_min="$START" \
  --data-urlencode query.start_time_max="$END" \
  --data-urlencode query.duration_min=500ms \
  --data-urlencode query.num_traces=5 \
  | jq -r '[.result.resourceSpans[].scopeSpans[].spans[].traceId] | unique | .[]'

TRACE_ID=$(curl -sG "$JAEGER/api/v3/traces" \
  --data-urlencode query.service_name=frontend \
  --data-urlencode query.start_time_min="$START" \
  --data-urlencode query.start_time_max="$END" \
  --data-urlencode query.num_traces=1 \
  | jq -r '.result.resourceSpans[0].scopeSpans[0].spans[0].traceId')

curl -s "$JAEGER/api/v3/traces/$TRACE_ID" \
  | jq '[.result.resourceSpans[].scopeSpans[].spans[]] | length'
curl -s "$JAEGER/api/v3/traces/$TRACE_ID" \
  | jq -r '[.result.resourceSpans[].resource.attributes[]
            | select(.key=="service.name") | .value.stringValue]
           | unique | join(",")'
```

Ожидаемый вывод (примерно так):

```text
jaeger
driver
mysql
redis-manual
customer
frontend
route
0a641c89b2908d00c7e33e57f97ff17d
2ab42bed22d0ba3039cf3bc29c00709b
39
customer,driver,frontend,mysql,redis-manual,route
```

Почему так: в OTLP JSON spans сгруппированы по ресурсу (сервису), поэтому
для подсчёта их «расплющивают» через `resourceSpans[].scopeSpans[].
spans[]`. Без временного окна API v3 не ищет traces — это защита от
полного сканирования хранилища. Старый API `/api/services`,
`/api/traces` был внутренним API UI Jaeger v1, в новых версиях v2 на
него полагаться нельзя.

## Упражнение 03 — Отправить кастомный trace через otel-cli

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4318"

otel-cli exec \
  --service "my-shell-script" \
  --name "data-processing" \
  --attrs "environment=lab,step=1" \
  --verbose \
  -- sleep 0.5

SOCK=$(mktemp -d)
otel-cli span background --service "my-script" --name "main" \
  --timeout 60 --sockdir "$SOCK" &
sleep 0.5
otel-cli span event --sockdir "$SOCK" --name "processing started"
sleep 1
otel-cli span end --sockdir "$SOCK"
wait

curl -s http://localhost:16686/api/v3/services | jq -r '.services[]' | grep my-
```

Ожидаемый вывод (примерно так):

```text
my-shell-script
my-script
```

Почему так: схема `http://` в endpoint переключает otel-cli на OTLP/HTTP,
поэтому нужен порт 4318; на `http://localhost:4317` (gRPC) он падает с
`malformed HTTP response` — и молча, если не указать `--verbose`
(или `--fail` для ненулевого кода выхода). `span background` держит
открытый span и принимает события через unix-сокет в `--sockdir`;
`span end` закрывает его и отправляет.

## Упражнение 04 — Инструментировать Python приложение

Готовое решение — [app.py](./app.py) (с `FlaskInstrumentor` и
`service.name`).

```bash
pip install flask opentelemetry-sdk opentelemetry-exporter-otlp \
  opentelemetry-instrumentation-flask
python app.py &
curl http://localhost:5000/
sleep 5   # BatchSpanProcessor отправляет пачками

START=$(date -u -d '-1 hour' +%Y-%m-%dT%H:%M:%SZ)
END=$(date -u -d '+1 min' +%Y-%m-%dT%H:%M:%SZ)
curl -sG http://localhost:16686/api/v3/traces \
  --data-urlencode query.service_name=flask-demo \
  --data-urlencode query.start_time_min="$START" \
  --data-urlencode query.start_time_max="$END" \
  | jq -c '[.result.resourceSpans[].scopeSpans[].spans[].name]'
```

Ожидаемый вывод (примерно так):

```text
Result: ok
["fetch-data","handle-index","GET /"]
```

Почему так: `FlaskInstrumentor` создаёт серверный span `GET /` на каждый
запрос, ручные spans `handle-index` → `fetch-data` становятся его
потомками через текущий контекст — итого три spans в одном trace. Без
`Resource` с `service.name` сервис появился бы в Jaeger как
`unknown_service`. `OTLPSpanExporter()` без аргументов берёт endpoint из
`OTEL_EXPORTER_OTLP_ENDPOINT` или по умолчанию `http://localhost:4317`.
