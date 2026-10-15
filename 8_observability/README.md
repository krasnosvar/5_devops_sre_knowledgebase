# Раздел 8. Observability

Три столпа наблюдаемости: метрики, логи, трейсинг. Как понять, что происходит
с системой в продакшне, не подключаясь к каждому контейнеру вручную.

> Практические команды → [`../1_sysadm_sre_devops_tools/.../4_monitoring_and_log_tools/`](../../1_sysadm_sre_devops_tools/1_linux/2_services/4_monitoring_and_log_tools/)

## Пререквизиты

- [3_containers](../3_containers/) и
  [0_lab_setup/01_docker_compose](../0_lab_setup/01_docker_compose/) —
  все стенды раздела (🐳 Tier 1) поднимаются через Docker Compose.
- [1_linux_and_shell](../1_linux_and_shell/) — ресурсы ОС (CPU, память,
  диск, сеть), которые мы будем измерять.
- [4_kubernetes](../4_kubernetes/) — для мест про service discovery,
  DaemonSet-агенты и Tier 2 (Helm в kind); без него Tier 1 проходится
  полностью.

## Подразделы

1. [01_observability_theory](./01_observability_theory/) — observability vs
   monitoring: в чём разница; три столпа (metrics, logs, traces) и когда каждый
   нужен; методологии метрик: RED (Rate/Errors/Duration), USE
   (Utilization/Saturation/Errors), Google's Four Golden Signals.

2. [02_metrics_prometheus](./02_metrics_prometheus/) — Prometheus: data model
   (metric types: counter/gauge/histogram/summary), scrape model, remote_write;
   PromQL от простого к сложному (rate, increase, histogram_quantile, recording
   rules); правила алертинга и типичные ошибки (alert fatigue, flapping).

3. [03_victoriametrics](./03_victoriametrics/) — VictoriaMetrics как
   альтернатива Prometheus: почему в 10–20 раз меньше памяти, MetricsQL отличия,
   single-node vs cluster, vmctl для миграции данных.

4. [04_grafana](./04_grafana/) — Grafana: datasources, dashboard provisioning
   как код (JSON + Helm), переменные и templating, alerting rules; разница между
   Grafana Alerts и Alertmanager; организация дашбордов для команды.

5. [05_logs_loki](./05_logs_loki/) — Loki: pull vs push модели сбора логов,
   Grafana Alloy / OTel Collector как агенты (Promtail — legacy, снят с
   поддержки); LogQL (label filters, parsing, metric queries); Loki vs
   Elasticsearch: когда что выбрать.

6. [06_tracing](./06_tracing/) — распределённый трейсинг: trace/span/context
   propagation; OpenTelemetry как стандарт (SDK, Collector, OTLP протокол);
   Jaeger v2 (построен на OTel Collector) vs Grafana Tempo; инструментация
   приложений (Go, Python).

7. [07_alerting](./07_alerting/) — проектирование алертинга: SLO-based alerts
   (burn rate) vs threshold alerts; Alertmanager (routing, inhibition, silences,
   PagerDuty/Slack интеграция); runbook как часть алерта; борьба с alert
   fatigue.

8. [08_dashboards_as_code](./08_dashboards_as_code/) — Grafana dashboards в Git:
   Grafonnet (Jsonnet), grafana-operator для k8s, provisioning через ConfigMap;
   review дашбордов как код.

9. [09_observability_at_scale](./09_observability_at_scale/) — когда один
   Prometheus перестаёт справляться: cardinality explosion как первая
   причина деградации (не объём), federation vs remote_write в кластерное
   хранилище (Thanos/VictoriaMetrics cluster), sampling и tiered retention
   для логов, дашборды и алертинг поверх множества кластеров.

## Как проходить

01 → 02 → 04 — базовый мониторинг-стек. 05 и 06 параллельно. 03 — если
Prometheus не справляется по ресурсам. 07 и 08 — после опыта с реальными
дашбордами. 09 — когда стек из 01-08 уже работает в проде на нескольких
кластерах и упирается в масштаб.

## Упражнения — тиры

🐳 Tier 1: весь стек (Prometheus + Grafana + Loki + Jaeger) через Docker Compose
🖥 Tier 2: деплой через Helm в kind/k3d кластер

## Когда двигаться дальше

- Можете поднять стек метрик + логов + трейсов и по одному инциденту
  пройти путь «алерт → дашборд → логи → трейс».
- Можете без подсказки написать PromQL-алерт с `for:` и LogQL-запрос
  «ошибки в минуту по сервису».
- Понимаете, где кончаются возможности single-node Prometheus/Loki.

Дальше — [9_sre](../9_sre/): SLO, error budget, инциденты.

## Связь

- Prometheus PromQL → [`../1_sysadm_sre_devops_tools/.../prometheus/prometheus.sh`](../../1_sysadm_sre_devops_tools/1_linux/2_services/4_monitoring_and_log_tools/prometheus/prometheus.sh)
- Loki logcli → [`../1_sysadm_sre_devops_tools/.../loki/loki.sh`](../../1_sysadm_sre_devops_tools/1_linux/2_services/4_monitoring_and_log_tools/loki/loki.sh)
- Tracing → [`../1_sysadm_sre_devops_tools/.../tracing/tracing.sh`](../../1_sysadm_sre_devops_tools/1_linux/2_services/4_monitoring_and_log_tools/tracing/tracing.sh)
