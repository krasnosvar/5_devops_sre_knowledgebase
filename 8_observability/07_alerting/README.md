# 07. Алертинг и Alertmanager

## Зачем
Алерт, на который нельзя отреагировать, или сотня алертов про одну
проблему — главные причины выгорания дежурных. Тема о том, как
Alertmanager группирует, маршрутизирует и подавляет алерты, и как
проектировать алерты по симптомам и burn rate, а не по каждому порогу.

## Пререквизиты
- [02_metrics_prometheus](../02_metrics_prometheus/) — alerting rules и
  простой `alertmanager.yml` из стенда.
- [01_observability_theory](../01_observability_theory/) — SLO и burn
  rate (подробно — в [9_sre/01_slo_sli_sla](../../9_sre/01_slo_sli_sla/)).

## Файлы
- [01_theory/alerting.md](./01_theory/alerting.md) — архитектура
  Alertmanager, grouping и дедупликация, routing и receivers,
  inhibition и silences, HA-кластер, вопросы с собеседований.
- [02_examples/alertmanager-full.yaml](./02_examples/alertmanager-full.yaml)
  — полный конфиг: маршруты на `matchers`, Slack и PagerDuty receivers,
  inhibit rule, шаблоны.

Отдельных упражнений нет: практика алертинга — в упражнениях 02
[по Prometheus](../02_metrics_prometheus/03_exercises/README.md) и 04
[по SLO](../../9_sre/01_slo_sli_sla/03_exercises/README.md).
Конфиг проверяется без стенда (из каталога темы):

```bash
docker run --rm --entrypoint amtool -v "$PWD/02_examples:/w:ro" \
  prom/alertmanager check-config /w/alertmanager-full.yaml
```

## Как проходить
1. Прочитать теорию.
2. Разобрать `alertmanager-full.yaml`: для алерта
   `severity=warning, env=production` пройти дерево маршрутов вручную.
3. Проверить конфиг `amtool check-config` (команда выше).

## Когда двигаться дальше
- Можете объяснить разницу `group_wait`, `group_interval` и
  `repeat_interval`.
- Можете написать inhibit rule «critical гасит warning на том же
  instance» на синтаксисе `source_matchers`/`target_matchers`.
- Понимаете, почему Prometheus шлёт алерты во все реплики Alertmanager
  и как реплики избегают дублей уведомлений (gossip).

Дальше — [08_dashboards_as_code](../08_dashboards_as_code/).
