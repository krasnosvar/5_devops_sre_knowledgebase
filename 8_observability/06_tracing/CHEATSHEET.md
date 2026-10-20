# Распределённая трассировка — шпаргалка

Подробности и объяснения — в [01_theory/](./01_theory/). ⚠️ — опасная
команда или частая ловушка.

## Понятия

Подробно: [01_distributed_tracing.md](./01_theory/01_distributed_tracing.md).

| Термин | Что это |
| :--- | :--- |
| Trace | дерево spans одного end-to-end запроса, общий `trace_id` (128 бит) |
| Span | единица работы: имя, `span_id` (64 бит), `parent_span_id`, start/end, атрибуты, события, статус |
| Context propagation | передача `trace_id`/`span_id` в заголовках между сервисами (inject → extract) |
| Attributes | ключ-значение только на своём span'е |
| Baggage | ключ-значение, которое едет по всей цепочке (заголовок `baggage`) |
| Exemplar | `trace_id`, прикреплённый к точке метрики-гистограммы |

## Заголовок W3C `traceparent`

```text
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
             │  └ trace-id: 32 hex               └ span-id: 16 hex │
             version (00)                                  flags (01 = sampled)
```

| Формат | Заголовки |
| :--- | :--- |
| W3C Trace Context (дефолт OTel) | `traceparent`, `tracestate` |
| W3C Baggage | `baggage: user_id=123` |
| B3 (Zipkin, старые mesh) | `X-B3-TraceId`, `X-B3-SpanId`, `X-B3-Sampled` или один `b3` |
| Выбор в SDK | `OTEL_PROPAGATORS=tracecontext,baggage` (добавить `b3` при смешанном парке) |

## OpenTelemetry SDK: переменные окружения

| Задача | Переменная / команда |
| :--- | :--- |
| Имя сервиса | `OTEL_SERVICE_NAME=orders` |
| Куда слать (OTLP) | `OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318` |
| Протокол | `OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf` (или `grpc` → порт 4317) |
| Атрибуты ресурса | `OTEL_RESOURCE_ATTRIBUTES=deployment.environment=prod,service.version=1.4.2` |
| Head sampling 10% с учётом родителя | `OTEL_TRACES_SAMPLER=parentbased_traceidratio`, `OTEL_TRACES_SAMPLER_ARG=0.1` |
| Python auto-instrumentation | `pip install opentelemetry-distro opentelemetry-exporter-otlp`<br>`opentelemetry-bootstrap -a install`<br>`opentelemetry-instrument python app.py` |
| Java агент | `java -javaagent:opentelemetry-javaagent.jar -jar app.jar` |
| Go | `otelhttp.NewHandler(h, "orders")`, `otelhttp.NewTransport(http.DefaultTransport)` |

⚠️ Порт 4317 — gRPC, 4318 — HTTP; перепутанный протокол даёт молчаливую
потерю спанов.

## Sampling: когда что

| Вариант | Где решается | Плюсы | Минусы |
| :--- | :--- | :--- | :--- |
| Head (`TraceIdRatioBased`) | в SDK на старте запроса | дёшево, без состояния | ⚠️ теряет редкие ошибки |
| `ParentBased(root=...)` | SDK, следует флагу `sampled` родителя | цельные трейсы | доля задаётся только в корне |
| Tail (`tail_sampling`) | Collector после `decision_wait` | все ошибки и медленные | RAM; все spans трейса на один Collector (`loadbalancing` exporter по `traceID`) |

## OTel Collector

Подробно: [02_tracing.md](./01_theory/02_tracing.md).

```yaml
receivers:
  otlp:
    protocols:
      grpc: {endpoint: 0.0.0.0:4317}
      http: {endpoint: 0.0.0.0:4318}
processors:
  memory_limiter: {check_interval: 1s, limit_mib: 512}   # первым
  attributes/scrub:
    actions:
      - {key: http.request.header.authorization, action: delete}
  tail_sampling:
    decision_wait: 10s
    policies:
      - {name: errors, type: status_code, status_code: {status_codes: [ERROR]}}
      - {name: slow, type: latency, latency: {threshold_ms: 1000}}
      - {name: rest, type: probabilistic, probabilistic: {sampling_percentage: 1}}
  batch: {}                                                # последним
connectors:
  spanmetrics: {}            # RED-метрики из спанов
exporters:
  otlp/tempo: {endpoint: tempo:4317, tls: {insecure: true}}
  prometheus: {endpoint: 0.0.0.0:8889}
  debug: {verbosity: normal}
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, attributes/scrub, tail_sampling, batch]
      exporters: [otlp/tempo, spanmetrics]
    metrics:
      receivers: [spanmetrics]
      exporters: [prometheus]
```

| Задача | Команда |
| :--- | :--- |
| Проверить конфиг | `otelcol-contrib validate --config=config.yaml` |
| Список компонентов сборки | `otelcol-contrib components` |
| Метрики самого Collector | `curl -s localhost:8888/metrics \| grep otelcol_exporter_send_failed` |
| ⚠️ Удалены | exporter `jaeger` (порт 14250) → `otlp`; exporter `logging` → `debug` |

## Порты

| Компонент | Порт |
| :--- | :--- |
| OTLP gRPC / HTTP | 4317 / 4318 |
| Collector: свои метрики | 8888 |
| Jaeger v2 UI и API | 16686 |
| Tempo HTTP API | 3200 |
| Zipkin | 9411 |

## Jaeger vs Tempo

| | Jaeger v2 | Grafana Tempo |
| :--- | :--- | :--- |
| Основа | сборка OTel Collector | отдельный бэкенд Grafana |
| Хранение | Elasticsearch/OpenSearch, Cassandra (лаба — memory/Badger) | объектное хранилище (S3/GCS), Parquet |
| Поиск | по тегам через индекс | по `trace_id`; TraceQL — сканированием колонок |
| Цена | дорогой индексируемый backend | дешёвое хранение |

```text
{ resource.service.name = "checkout" && span.http.response.status_code >= 500 }
{ duration > 2s }
```

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| Два несвязанных трейса вместо дерева | нет propagation: HTTP-клиент не инструментирован, разные propagators (B3 vs W3C) |
| Дочерний span начинается раньше родителя | clock skew: NTP/chrony на нодах |
| Спаны не доходят | порт/протокол 4317 vs 4318, `debug` exporter, `otelcol_receiver_refused_spans` |
| Collector OOM | нет `memory_limiter`, велик `decision_wait` в tail sampling |
| Нет перехода лог → трейс | `trace_id` не пишется в лог; Derived fields в datasource Loki |
| Трейсы с ошибками теряются | head sampling: перейти на tail sampling |

> Проверка: конфиг Collector выше прошёл `otelcol-contrib validate`
> (otel/opentelemetry-collector-contrib 0.162.0), формат `traceparent`
> сверен со спецификацией W3C; не проверено: TraceQL-запросы (нет
> запущенного Tempo), переменные SDK — по спецификации OTel, без запуска.
