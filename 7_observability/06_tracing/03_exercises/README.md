# Упражнения — Distributed Tracing

Стенд: 🐳 Tier 1 — `7_observability/06_tracing/02_examples/`

```bash
cd ../02_examples/
docker compose up -d
# Jaeger UI: http://localhost:16686
# Demo App (генерирует traces): http://localhost:8080
```

## 01 — Explore traces в Jaeger UI

1. Открыть http://localhost:8080 — нажать несколько кнопок в demo app
2. Открыть http://localhost:16686

```
- Service: выбрать "frontend"
- Operation: выбрать любую операцию
- Find Traces → посмотреть список traces
- Кликнуть на trace → развернуть spans
```

Ответить на вопросы:
- Сколько сервисов участвует в одном запросе?
- Какой span занимает больше всего времени?
- Есть ли spans с ошибками?

## 02 — Jaeger API

```bash
JAEGER="http://localhost:16686"

# Список сервисов с трейсами
curl -s "$JAEGER/api/services" | jq '.data[]'

# Найти медленные traces (> 500ms)
curl -s "$JAEGER/api/traces?service=frontend&minDuration=500ms&limit=5" \
  | jq '.data[].traceID'

# Посмотреть конкретный trace
TRACE_ID=$(curl -s "$JAEGER/api/traces?service=frontend&limit=1" | jq -r '.data[0].traceID')
curl -s "$JAEGER/api/traces/$TRACE_ID" | jq '.data[0].spans | length'
echo "spans in trace"
```

## 03 — Отправить кастомный trace через otel-cli

```bash
# Установить otel-cli
# https://github.com/equinix-labs/otel-cli

export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"

# Создать span вручную
otel-cli exec \
  --service "my-shell-script" \
  --name "data-processing" \
  --attrs "environment=lab,step=1" \
  -- sleep 0.5

# Вложенные spans
otel-cli span background --service "my-script" --name "main"
otel-cli span event --name "processing started"
sleep 1
otel-cli span end

# Проверить в Jaeger: service = "my-shell-script"
```

## 04 — Инструментировать Python приложение

```python
# app.py — минимальное Flask приложение с OTel
# pip install flask opentelemetry-distro opentelemetry-exporter-otlp

from flask import Flask
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

# Настроить OTel
provider = TracerProvider()
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
# Проверить trace в Jaeger — должен быть сервис с двумя spans
```
