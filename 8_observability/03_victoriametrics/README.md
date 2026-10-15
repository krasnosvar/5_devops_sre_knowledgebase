# 03. VictoriaMetrics

## Зачем
Когда одному Prometheus не хватает памяти или нужно долговременное
хранение с несколькими кластерами-источниками, ищут совместимую
альтернативу. VictoriaMetrics принимает те же метрики и PromQL
(расширенный до MetricsQL), но расходует заметно меньше ресурсов и
масштабируется в кластерный режим.

## Пререквизиты
- [02_metrics_prometheus](../02_metrics_prometheus/) — scrape-модель,
  `remote_write`, PromQL.
- [0_lab_setup/01_docker_compose](../../0_lab_setup/01_docker_compose/)
  — запуск стенда.

## Файлы
- [01_theory/victoriametrics.md](./01_theory/victoriametrics.md) —
  ограничения Prometheus, single-node vs cluster, vmagent/vminsert/
  vmstorage/vmselect, MetricsQL, мультитенантность, вопросы с
  собеседований.
- [02_examples/](./02_examples/) — стенд: `docker-compose.yml`
  (VictoriaMetrics single-node, vmagent, node-exporter, Grafana),
  `vmagent.yaml` (scrape-конфиг), `datasource.yaml` (VM как Prometheus
  datasource в Grafana).

Отдельных упражнений нет: стенд повторяет лабу Prometheus, но с
vmagent → `remote_write` → VictoriaMetrics; запросы из
[упражнений по PromQL](../02_metrics_prometheus/03_exercises/README.md)
выполняются в Grafana (http://localhost:3000) без изменений.

## Как проходить
1. Прочитать теорию.
2. Поднять стенд: `cd 02_examples && docker compose up -d`; открыть
   UI vmagent http://localhost:8429/targets и VMUI
   http://localhost:8428/vmui.
3. Выполнить в VMUI запросы из упражнения 01 по PromQL и сравнить с
   Prometheus.

## Когда двигаться дальше
- Можете объяснить, когда VictoriaMetrics оправдана, а когда хватает
  Prometheus.
- Можете нарисовать путь метрики в кластерном режиме: vmagent →
  vminsert → vmstorage ← vmselect.
- Знаете хотя бы два отличия MetricsQL от PromQL.

Дальше — [04_grafana](../04_grafana/).
