# Раздел 7. Observability

Три столпа наблюдаемости: метрики, логи, трейсинг. Как понять, что происходит
с системой в продакшне, не подключаясь к каждому контейнеру вручную.

> Практические команды → [`../1_sysadm_sre_devops_tools/.../4_monitoring_and_log_tools/`](../../1_sysadm_sre_devops_tools/1_linux/2_services/4_monitoring_and_log_tools/)

## Подразделы

1. [01_observability_theory](./01_observability_theory/) — observability vs monitoring:
   в чём разница; три столпа (metrics, logs, traces) и когда каждый нужен;
   методологии метрик: RED (Rate/Errors/Duration), USE (Utilization/Saturation/Errors),
   Google's Four Golden Signals.

2. [02_metrics_prometheus](./02_metrics_prometheus/) — Prometheus: data model
   (metric types: counter/gauge/histogram/summary), scrape model, remote_write;
   PromQL от простого к сложному (rate, increase, histogram_quantile, recording rules);
   правила алертинга и типичные ошибки (alert fatigue, flapping).

3. [03_victoriametrics](./03_victoriametrics/) — VictoriaMetrics как альтернатива
   Prometheus: почему в 10–20 раз меньше памяти, MetricsQL отличия, single-node
   vs cluster, vmctl для миграции данных.

4. [04_grafana](./04_grafana/) — Grafana: datasources, dashboard provisioning как код
   (JSON + Helm), переменные и templating, alerting rules; разница между
   Grafana Alerts и Alertmanager; организация дашбордов для команды.

5. [05_logs_loki](./05_logs_loki/) — Loki: pull vs push модели сбора логов,
   Promtail/Alloy/OTel collector как агенты; LogQL (label filters, parsing,
   metric queries); Loki vs Elasticsearch: когда что выбрать.

6. [06_tracing](./06_tracing/) — распределённый трейсинг: trace/span/context
   propagation; OpenTelemetry как стандарт (SDK, Collector, OTLP протокол);
   Jaeger vs Grafana Tempo; TraceQL; инструментация приложений (Go, Python, Java).

7. [07_alerting](./07_alerting/) — проектирование алертинга: SLO-based alerts
   (burn rate) vs threshold alerts; Alertmanager (routing, inhibition, silences,
   PagerDuty/Slack интеграция); runbook как часть алерта; борьба с alert fatigue.

8. [08_dashboards_as_code](./08_dashboards_as_code/) — Grafana dashboards в Git:
   Grafonnet (Jsonnet), grafana-operator для k8s, provisioning через ConfigMap;
   review дашбордов как код.

## Как проходить

01 → 02 → 04 — базовый мониторинг-стек. 05 и 06 параллельно. 03 — если
Prometheus не справляется по ресурсам. 07 и 08 — после опыта с реальными
дашбордами.

## Упражнения — тиры

🐳 Tier 1: весь стек (Prometheus + Grafana + Loki + Jaeger) через Docker Compose
🖥 Tier 2: деплой через Helm в kind/k3d кластер

## Связь

- Prometheus PromQL → [`../1_sysadm_sre_devops_tools/.../prometheus/prometheus.sh`](../../1_sysadm_sre_devops_tools/1_linux/2_services/4_monitoring_and_log_tools/prometheus/prometheus.sh)
- Loki logcli → [`../1_sysadm_sre_devops_tools/.../loki/loki.sh`](../../1_sysadm_sre_devops_tools/1_linux/2_services/4_monitoring_and_log_tools/loki/loki.sh)
- Tracing → [`../1_sysadm_sre_devops_tools/.../tracing/tracing.sh`](../../1_sysadm_sre_devops_tools/1_linux/2_services/4_monitoring_and_log_tools/tracing/tracing.sh)
