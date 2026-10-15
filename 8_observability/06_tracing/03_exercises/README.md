# Упражнения — Distributed Tracing

Стенд: 🐳 Tier 1 — `8_observability/06_tracing/02_examples/`

```bash
cd ../02_examples/
docker compose up -d
# Jaeger UI: http://localhost:16686
# Demo App HotROD (генерирует traces): http://localhost:8080
# OTLP для своих приложений: localhost:4317 (gRPC), localhost:4318 (HTTP)
```

Поток данных: приложение → OTLP → OTel Collector
(`otel-collector-config.yaml`: exporter `otlp/jaeger` + `debug`) →
Jaeger v2 (хранение в памяти, UI и API).

## 01 — Explore traces в Jaeger UI

1. Открыть http://localhost:8080 — нажать несколько кнопок клиентов
   (заказать машину) в HotROD
2. Открыть http://localhost:16686

```
- Service: выбрать "frontend"
- Operation: выбрать любую операцию (например, "GET /dispatch")
- Find Traces → посмотреть список traces
- Кликнуть на trace → развернуть spans
```

Ответить на вопросы:
- Сколько сервисов участвует в одном запросе?
- Какой span занимает больше всего времени?
- Есть ли spans с ошибками?

## 02 — Jaeger API

Jaeger v2 отдаёт HTTP API `/api/v3/*` — ответы в формате OTLP JSON
(`resourceSpans → scopeSpans → spans`). Поиск traces требует временного
окна (`query.start_time_min/max`, RFC 3339).

```bash
JAEGER="http://localhost:16686"
START=$(date -u -d '-1 hour' +%Y-%m-%dT%H:%M:%SZ)
END=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Список сервисов с трейсами
curl -s "$JAEGER/api/v3/services" | jq -r '.services[]'

# Найти медленные traces (> 500ms)
curl -sG "$JAEGER/api/v3/traces" \
  --data-urlencode query.service_name=frontend \
  --data-urlencode query.start_time_min="$START" \
  --data-urlencode query.start_time_max="$END" \
  --data-urlencode query.duration_min=500ms \
  --data-urlencode query.num_traces=5 \
  | jq -r '[.result.resourceSpans[].scopeSpans[].spans[].traceId] | unique | .[]'

# TODO: взять один traceId и через /api/v3/traces/<traceId> посчитать,
# сколько в нём spans и какие сервисы в нём участвуют
```

## 03 — Отправить кастомный trace через otel-cli

```bash
# Установить otel-cli: https://github.com/equinix-labs/otel-cli
# (бинарник из releases или образ ghcr.io/equinix-labs/otel-cli)

# otel-cli по схеме http:// выбирает OTLP/HTTP — значит порт 4318.
# (http://localhost:4317 не сработает: там gRPC.)
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4318"

# Создать span вокруг команды
otel-cli exec \
  --service "my-shell-script" \
  --name "data-processing" \
  --attrs "environment=lab,step=1" \
  -- sleep 0.5

# Долгий span с событиями: background-процесс слушает unix-сокет
SOCK=$(mktemp -d)
otel-cli span background --service "my-script" --name "main" \
  --timeout 60 --sockdir "$SOCK" &
sleep 0.5
otel-cli span event --sockdir "$SOCK" --name "processing started"
sleep 1
otel-cli span end --sockdir "$SOCK"

# Проверить в Jaeger: service = "my-shell-script" и "my-script"
```

## 04 — Инструментировать Python приложение

```python
# app.py — минимальное Flask приложение с OTel
# pip install flask opentelemetry-sdk opentelemetry-exporter-otlp

from flask import Flask
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

# Настроить OTel (service.name — имя сервиса в Jaeger)
provider = TracerProvider(resource=Resource.create({"service.name": "flask-demo"}))
provider.add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter(endpoint="http://localhost:4317", insecure=True))
)
trace.set_tracer_provider(provider)
tracer = trace.get_tracer(__name__)

app = Flask(__name__)

@app.route("/")
def index():
    with tracer.start_as_current_span("handle-request") as span:
        span.set_attribute("user.id", "42")
        result = process_data()
        return f"Result: {result}"

def process_data():
    with tracer.start_as_current_span("process-data"):
        import time; time.sleep(0.1)
        return "ok"

if __name__ == "__main__":
    app.run(port=5000)
```

```bash
python app.py
curl http://localhost:5000
# Проверить trace в Jaeger: сервис flask-demo с двумя spans
```

**Задача:** добавить авто-инструментацию Flask
(`opentelemetry-instrumentation-flask`, `FlaskInstrumentor`), чтобы
каждый HTTP-запрос получал серверный span автоматически, и убедиться,
что в trace стало три spans.
