# 05. Логи: Loki и LogQL

## Зачем
Метрика говорит «ошибок стало больше», а лог — какая именно ошибка и
у какого запроса. Loki хранит логи дёшево (индексирует только метки) и
отвечает на запросы LogQL в той же Grafana, где метрики и трейсы. На
работе это поиск причины инцидента и метрики из логов там, где
приложение метрик не отдаёт.

## Пререквизиты
- [02_metrics_prometheus](../02_metrics_prometheus/) — метки, селекторы
  и `rate()`: LogQL построен по образцу PromQL.
- [04_grafana](../04_grafana/) — Explore и datasources.
- [3_containers](../../3_containers/) — как Docker хранит stdout
  контейнеров (агент читает логи через Docker API).

> **Забегание вперёд.** Сбор логов в Kubernetes (DaemonSet, `hostPath`
> `/var/log/pods`) разбирается в теории и опирается на
> [4_kubernetes](../../4_kubernetes/). Для этой темы достаточно знать,
> что такое под и DaemonSet. Если Kubernetes ещё не освоен — эти места
> можно пропустить и вернуться к ним позже.

## Файлы
- [01_theory/01_loki.md](./01_theory/01_loki.md) — архитектура Loki
  против ELK, агенты сбора (Alloy, legacy Promtail), LogQL, хранение
  чанков, вопросы с собеседований. Читать первым.
- [01_theory/02_loki_logql.md](./01_theory/02_loki_logql.md) — практика:
  метки, LogQL (фильтры, парсеры, metric queries), конфиги Alloy и
  Promtail, полезные запросы.
- [02_examples/](./02_examples/) — стенд: `docker-compose.yml` (Loki,
  Grafana Alloy, Grafana, генератор логов flog; Promtail — в профиле
  `promtail`), `alloy-config.alloy`, `promtail-config.yaml` (legacy),
  `loki-config.yaml`, `grafana-datasources.yaml`.
- [03_exercises/README.md](./03_exercises/README.md) — 4 упражнения
  (LogQL, logcli, push API, pipeline в Alloy), 🐳 Tier 1.
- [04_exercises_answers/](./04_exercises_answers/) — ответы
  `logql-answers.md` и готовый блок `alloy-pipeline.alloy`.

## Как проходить
1. Прочитать `01_loki.md`, затем `02_loki_logql.md`.
2. Поднять стенд из `02_examples/`, дождаться `ready` на
   `curl -s localhost:3100/ready`, посмотреть граф компонентов в UI
   Alloy (http://localhost:12345).
3. Сделать упражнения по порядку.
4. Сверить с ответами.

## Когда двигаться дальше
- Можете объяснить, почему `trace_id` или `user_id` нельзя делать
  меткой Loki.
- Можете без подсказки написать запрос «количество 5xx в минуту по
  сервису» на LogQL.
- Можете прочитать конфиг Alloy и сказать, какой компонент что делает.

Дальше — [06_tracing](../06_tracing/).
