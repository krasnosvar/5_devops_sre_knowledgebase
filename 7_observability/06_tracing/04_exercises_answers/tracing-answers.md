# Ответы: Distributed Tracing упражнения

## Упражнение 02 — Jaeger API

```bash
JAEGER="http://localhost:16686"

# Список сервисов
curl -s "$JAEGER/api/services" | jq -r '.data[]'

# Медленные traces > 500ms
curl -s "$JAEGER/api/traces?service=frontend&minDuration=500ms&limit=5" \
    | jq -r '.data[].traceID'

# Конкретный trace
TRACE_ID=$(curl -s "$JAEGER/api/traces?service=frontend&limit=1" \
    | jq -r '.data[0].traceID')
curl -s "$JAEGER/api/traces/$TRACE_ID" \
    | jq '{spans: (.data[0].spans | length), duration: .data[0].spans[0].duration}'
```

## Упражнение 03 — otel-cli

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"

# Span для shell скрипта
otel-cli exec \
    --service "my-shell-script" \
    --name "data-processing" \
    --attrs "environment=lab,step=1" \
    -- sleep 0.5

# В Jaeger UI: service = "my-shell-script"
```

## Упражнение 04 — Instrumented Flask app

```python
# app.py — рабочее решение
from flask import Flask
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor
import time

# Настройка OTel
provider = TracerProvider()
provider.add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter(
        endpoint="http://localhost:4317",
        insecure=True
    ))
)
trace.set_tracer_provider(provider)
tracer = trace.get_tracer(__name__)

app = Flask(__name__)
FlaskInstrumentor().instrument_app(app)   # автоматически трейсит все HTTP запросы

@app.route("/")
def index():
    with tracer.start_as_current_span("handle-index") as span:
        span.set_attribute("user.type", "anonymous")
        result = fetch_data()
        return f"Result: {result}"

def fetch_data():
    with tracer.start_as_current_span("fetch-data"):
        time.sleep(0.05)  # имитация БД запроса
        return "ok"

if __name__ == "__main__":
    app.run(port=5000)

# Запуск: python app.py
# Тест: curl http://localhost:5000
# Результат в Jaeger: 2 spans (handle-index → fetch-data)
```
