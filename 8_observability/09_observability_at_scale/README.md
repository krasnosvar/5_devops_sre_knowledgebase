# 09. Observability на масштабе

## Зачем
Стек из одного Prometheus и одного Loki перестаёт справляться на
десятках кластеров и тысячах хостов: память съедает cardinality,
запросы тормозят, хранить всё дорого. Тема — о том, что ломается первым
и как переходить к federation/remote_write, глобальным хранилищам и
tiered retention.

## Пререквизиты
- [02_metrics_prometheus](../02_metrics_prometheus/),
  [03_victoriametrics](../03_victoriametrics/),
  [05_logs_loki](../05_logs_loki/) — single-node инструменты, о
  пределах которых идёт речь.
- [4_kubernetes](../../4_kubernetes/) — мультикластерный контекст;
  также см. [14_system_design/02_single_vs_multi_cluster](../../14_system_design/02_single_vs_multi_cluster/).

## Файлы
- [01_theory/observability_at_scale.md](./01_theory/observability_at_scale.md)
  — cardinality как первая причина деградации, federation vs
  remote_write (Thanos, VictoriaMetrics cluster), управление
  cardinality на источнике, sampling и tiered retention логов,
  дашборды и алертинг поверх многих кластеров, вопросы с собеседований.

Без лабы: проблема масштаба не воспроизводится на локальном стенде
(объяснение — в начале теории).

## Как проходить
1. Прочитать теорию.
2. На стенде [02_metrics_prometheus](../02_metrics_prometheus/02_examples/)
   найти топ метрик по числу серий:
   `topk(10, count by (__name__) ({__name__=~".+"}))` — это первый шаг
   любого разбора cardinality.

## Когда двигаться дальше
- Можете объяснить, почему cardinality, а не объём данных, первой
  кладёт Prometheus.
- Можете сравнить federation и remote_write и назвать, когда что.
- Можете предложить схему хранения логов с разным retention для
  разных классов логов.

Раздел завершён — дальше [9_sre](../../9_sre/).
