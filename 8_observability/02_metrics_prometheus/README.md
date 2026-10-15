# 02. Метрики: Prometheus и PromQL

## Зачем
Метрики — самый дешёвый и быстрый сигнал о состоянии системы: по ним
строят дашборды, алерты и SLO. Prometheus — де-факто стандарт для
метрик в Kubernetes-мире; PromQL нужен каждый раз, когда вы пишете
алерт, recording rule или панель Grafana.

## Пререквизиты
- [01_observability_theory](../01_observability_theory/) — типы
  сигналов, RED/USE.
- [0_lab_setup/01_docker_compose](../../0_lab_setup/01_docker_compose/)
  — стенд поднимается через `docker compose up -d`.
- Для упражнения 04 — базовый Python (`pip install`, запуск скрипта).

> **Забегание вперёд.** Service discovery в Kubernetes
> (`kubernetes_sd_configs`) в теории опирается на
> [4_kubernetes](../../4_kubernetes/). Для этой темы достаточно: под,
> label, annotation. Если Kubernetes ещё не освоен — §4 теории можно
> пропустить и вернуться к нему позже.

## Файлы
- [01_theory/01_prometheus.md](./01_theory/01_prometheus.md) — pull-модель,
  data model и кардинальность, типы метрик, service discovery, HA и
  долговременное хранение, вопросы с собеседований. Читать первым.
- [01_theory/02_promql.md](./01_theory/02_promql.md) — PromQL: операторы,
  `rate`/`increase`, агрегации, `histogram_quantile`, практические
  запросы.
- [02_examples/](./02_examples/) — стенд: `docker-compose.yml`
  (Prometheus, Grafana, node-exporter, Alertmanager), `prometheus.yml`,
  `alertmanager.yml`, `grafana-datasources.yaml`, каталог `alerts/` для
  rule-файлов.
- [03_exercises/README.md](./03_exercises/README.md) — 4 упражнения
  (PromQL, alerting rules, recording rules, своё приложение), 🐳 Tier 1.
- [04_exercises_answers/](./04_exercises_answers/) — ответы
  `promql-answers.md`, готовые `node-alerts.yml`, `recording.yml`,
  `app.py`.

## Как проходить
1. Прочитать `01_prometheus.md`, затем `02_promql.md`.
2. Поднять стенд из `02_examples/`, открыть http://localhost:9090/targets
   — все targets должны быть `UP`.
3. Сделать упражнения по порядку, каждый rule-файл проверять
   `promtool check rules`.
4. Сверить с ответами.

## Когда двигаться дальше
- Можете объяснить, почему к counter применяют `rate()`, а к gauge — нет.
- Можете без подсказки написать алерт с `for:` и recording rule с
  правильным именем `level:metric:operations`.
- Понимаете, что такое cardinality и почему `user_id` в метке — плохо.

Дальше — [03_victoriametrics](../03_victoriametrics/) (или сразу
[04_grafana](../04_grafana/), если ресурсов Prometheus хватает).
