# Distributed Tracing — теория

## Зачем нужен трейсинг

В монолите: stacktrace показывает путь запроса.
В микросервисах: запрос проходит через 10 сервисов — обычные логи не покажут где именно медленно или сломано.

**Трейс** решает это: видишь весь путь запроса, время в каждом сервисе, причину ошибки.

## Ключевые понятия

**Trace** — дерево spans, представляющее один end-to-end запрос.

**Span** — единица работы: один вызов функции/сервиса/БД.
Содержит: имя, trace_id, span_id, parent_span_id, timestamps, tags, logs.

**Context Propagation** — передача trace_id между сервисами через HTTP заголовки.

```
Trace abc123 (весь запрос: 320ms)
├── api-gateway (15ms)
│   └── auth-service.Validate (5ms)
└── order-service.CreateOrder (300ms)
    ├── inventory-service.CheckStock (10ms)
    ├── payment-service.Charge (250ms)    ← узкое место
    │   └── stripe-api (240ms)           ← внешний вызов медленный
    └── notification-service.Send (40ms)
```

## OpenTelemetry — стандарт индустрии

OTel заменяет Jaeger SDK, Zipkin SDK, AWS X-Ray SDK.
Одна инструментация → любой backend.

```
Ваше приложение
    │  OTel SDK (traces + metrics + logs)
    ▼
OTel Collector (собирает, обрабатывает, маршрутизирует)
    │
    ├── Traces → Jaeger / Tempo
    ├── Metrics → Prometheus
    └── Logs → Loki
```

### Инструментация приложения

```python
# Python — auto-instrumentation (без изменения кода)
# pip install opentelemetry-distro opentelemetry-exporter-otlp
opentelemetry-instrument \
  --exporter_otlp_endpoint http://otel-collector:4318 \
  python myapp.py

# Manual instrumentation — для кастомных span'ов
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter

tracer = trace.get_tracer(__name__)

def process_order(order_id: str):
    with tracer.start_as_current_span("process_order") as span:
        span.set_attribute("order.id", order_id)
        span.set_attribute("order.amount", get_amount(order_id))

        try:
            result = charge_payment(order_id)
            span.set_attribute("payment.status", "success")
            return result
        except Exception as e:
            span.set_status(trace.StatusCode.ERROR, str(e))
            span.record_exception(e)
            raise
```

```go
// Go — auto-instrumentation для http.Client и http.Server
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/trace"
    "go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
)

// обернуть HTTP handler
http.Handle("/api/orders", otelhttp.NewHandler(handler, "orders"))

// обернуть HTTP client
client := &http.Client{
    Transport: otelhttp.NewTransport(http.DefaultTransport),
}

// создать span вручную
tracer := otel.Tracer("myservice")
ctx, span := tracer.Start(ctx, "charge-payment")
defer span.End()
span.SetAttributes(attribute.String("payment.method", "card"))
```

## Context Propagation — как trace_id путешествует

```
Сервис A                           Сервис B
────────                           ────────
span = start("handle-request")
ctx = inject(span.context)         
→ HTTP запрос с заголовком →
  traceparent: 00-abc123-def456-01

                                   span = extract(headers)
                                   child_span = start("process", parent=span)
                                   ...
                                   child_span.end()
span.end()
```

**W3C Trace Context** (стандарт):
```
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
             │  ────────────────────────────────  ────────────────  │
             │  trace-id (128 bit)                span-id (64 bit)  │
             version                                                 flags (sampled)
```

## Sampling — не трейсить всё

В production трейсить 100% запросов дорого. Sampling решает что трейсить.

**Head-based sampling** — решение принимается при создании trace:
```python
# Трейсить 10% запросов
sampler = TraceIdRatioBased(0.1)

# Трейсить все с ошибками + 1% остальных
sampler = ParentBased(root=TraceIdRatioBased(0.01))
```

**Tail-based sampling** — решение после завершения trace (можно сохранить все с ошибками):
- Настраивается в OTel Collector
- Позволяет: "сохранять все traces дольше 1 секунды или с ошибкой, 1% остальных"

```yaml
# otel-collector-config.yaml — tail sampling
processors:
  tail_sampling:
    decision_wait: 10s
    policies:
      - name: errors-policy
        type: status_code
        status_code: {status_codes: [ERROR]}
      - name: slow-policy
        type: latency
        latency: {threshold_ms: 1000}
      - name: probabilistic
        type: probabilistic
        probabilistic: {sampling_percentage: 1}
```

## Связка: Trace ID в логах

```python
# добавить trace_id в каждый лог запроса
import logging
from opentelemetry import trace

class TraceContextFilter(logging.Filter):
    def filter(self, record):
        span = trace.get_current_span()
        ctx = span.get_span_context()
        record.trace_id = format(ctx.trace_id, '032x') if ctx.is_valid else ''
        record.span_id = format(ctx.span_id, '016x') if ctx.is_valid else ''
        return True

# В Grafana: кликнуть на trace_id в логах → автоматически открыть Tempo
```
