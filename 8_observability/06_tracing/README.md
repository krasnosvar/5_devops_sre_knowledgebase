# 06. Распределённый трейсинг

## Зачем
В микросервисах один запрос пользователя проходит через десяток
сервисов, и ни метрики, ни логи отдельного сервиса не покажут, где
именно он тормозит. Трейс показывает весь путь запроса с временем на
каждом шаге. OpenTelemetry — стандарт инструментации, Jaeger и Tempo —
типичные хранилища.

## Пререквизиты
- [01_observability_theory](../01_observability_theory/) — три столпа.
- [05_logs_loki](../05_logs_loki/) — связка «trace_id в логах → трейс».
- [0_lab_setup/01_docker_compose](../../0_lab_setup/01_docker_compose/)
  — стенд; для упражнения 04 — базовый Python, для 02 — `curl` и `jq`.

## Файлы
- [01_theory/01_distributed_tracing.md](./01_theory/01_distributed_tracing.md)
  — trace/span, OpenTelemetry SDK и Collector, context propagation
  (W3C `traceparent`), sampling, trace_id в логах. Читать первым.
- [01_theory/02_tracing.md](./01_theory/02_tracing.md) — углубление:
  OTel как стандарт, Jaeger v2 (на базе OTel Collector) vs Grafana Tempo,
  вопросы с собеседований.
- [02_examples/](./02_examples/) — стенд: `docker-compose.yml`
  (OTel Collector, Jaeger v2, демо-приложение HotROD) и
  `otel-collector-config.yaml` (OTLP → Jaeger и `debug`).
- [03_exercises/README.md](./03_exercises/README.md) — 4 упражнения
  (Jaeger UI, Jaeger API v3, otel-cli, инструментация Flask),
  🐳 Tier 1.
- [04_exercises_answers/](./04_exercises_answers/) — ответы
  `tracing-answers.md` и готовый `app.py`.

## Как проходить
1. Прочитать `01_distributed_tracing.md`, затем `02_tracing.md`.
2. Поднять стенд из `02_examples/`, понажимать кнопки в HotROD
   (http://localhost:8080) и найти traces в Jaeger
   (http://localhost:16686).
3. Сделать упражнения по порядку.
4. Сверить с ответами.

## Когда двигаться дальше
- Можете объяснить, как trace_id попадает из сервиса A в сервис B.
- Можете сказать, чем head-based sampling отличается от tail-based и
  где настраивается каждый.
- Можете инструментировать небольшое приложение и найти его trace в
  Jaeger без подсказки.

Дальше — [07_alerting](../07_alerting/).
