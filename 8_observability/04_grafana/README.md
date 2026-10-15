# 04. Grafana

## Зачем
Метрики, логи и трейсы бесполезны, пока их нельзя быстро посмотреть
вместе. Grafana — общий интерфейс к Prometheus, Loki, Tempo/Jaeger:
дашборды для дежурных, переменные для навигации по хостам и сервисам,
собственный алертинг.

## Пререквизиты
- [02_metrics_prometheus](../02_metrics_prometheus/) — PromQL и
  работающий стенд: упражнения используют Prometheus + Grafana из
  `02_metrics_prometheus/02_examples/`.
- Для упражнения 04 — `curl` и `jq`.

## Файлы
- [01_theory/grafana.md](./01_theory/grafana.md) — datasources,
  переменные и chaining, Unified Alerting, аутентификация и RBAC,
  provisioning, вопросы с собеседований.
- [02_examples/](./02_examples/) — `grafana-provisioning.yaml`
  (dashboard provider для провижининга из файлов) и
  `node-dashboard.json` (пример дашборда node-exporter в JSON).
- [03_exercises/README.md](./03_exercises/README.md) — 4 упражнения
  (дашборд вручную, переменные, alert rule, экспорт/импорт через API),
  🐳 Tier 1.
- [04_exercises_answers/grafana-answers.md](./04_exercises_answers/grafana-answers.md)
  — ответы.

## Как проходить
1. Прочитать теорию.
2. Поднять стенд из
   [02_metrics_prometheus/02_examples/](../02_metrics_prometheus/02_examples/)
   — datasource Prometheus подключится автоматически.
3. Сделать упражнения по порядку (04 опирается на дашборд из 01).
4. Сверить с ответами; посмотреть JSON из `02_examples/` как образец
   структуры дашборда.

## Когда двигаться дальше
- Можете собрать дашборд с переменной `$instance` без подсказок.
- Можете объяснить разницу между Grafana Alerting и правилами
  Prometheus + Alertmanager.
- Можете экспортировать дашборд через API и импортировать его обратно.

Дальше — [05_logs_loki](../05_logs_loki/).
