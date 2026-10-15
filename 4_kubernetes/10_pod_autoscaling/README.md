# 10. Автоскейлинг подов: HPA, VPA, KEDA

## Зачем
Нагрузка меняется в течение дня, а держать реплики "на пик"
круглосуточно дорого. HPA добавляет и убирает поды по метрикам, VPA
подбирает `requests` под реальное потребление, KEDA масштабирует по
внешним событиям (очереди) и умеет опускать консьюмеров до нуля.
Ошибки здесь типичны и дороги: HPA без `requests`, флаппинг реплик,
VPA и HPA, дерущиеся за одну метрику.

## Пререквизиты
- [05_scheduling](../05_scheduling/) — `requests`/`limits`: от них
  считается утилизация.
- [02_workloads](../02_workloads/) — Deployment, `kubectl scale`.
- [07_manifests_management/02_helm](../07_manifests_management/02_helm/)
  — KEDA ставится Helm-чартом.

## Файлы
- [01_theory/pod_autoscaling.md](./01_theory/pod_autoscaling.md) —
  источник метрик и формула HPA, зачем `requests`, stabilization
  window, VPA и конфликт с HPA, KEDA и scale-to-zero.
- [02_examples/](./02_examples/) — `hpa.yaml` (CPU + behavior),
  `vpa.yaml`, `keda-scaledobject.yaml` (Kafka-триггер).
- [03_exercises/README.md](./03_exercises/README.md) — 3 упражнения,
  🐳 Tier 1 (kind + metrics-server).
- [04_exercises_answers/](./04_exercises_answers/) —
  [hpa-answers.md](./04_exercises_answers/hpa-answers.md),
  `hpa-answer.yaml`, `keda-redis-answer.yaml` (scale-to-zero на Redis
  List).

Автоскейлинг нод — отдельная тема:
[08_cluster_operations/02_node_autoscaling](../08_cluster_operations/02_node_autoscaling/).

## Как проходить
1. Теория.
2. Поднять kind и metrics-server по началу упражнений.
3. Упражнения 01-03, сверка с ответами.

## Когда двигаться дальше
- Можете посчитать по формуле, сколько реплик выставит HPA.
- Знаете, почему HPA показывает `<unknown>` и как это исправить.
- Можете объяснить, кто делает переход 0 → 1 при KEDA и кто 1 → N.
- Знаете, почему VPA и HPA нельзя вешать на одну метрику.

Дальше — [11_operators_and_crds](../11_operators_and_crds/).
