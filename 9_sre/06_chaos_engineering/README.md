# 06. Chaos Engineering

## Зачем
Отказоустойчивость, которую не проверяли, — гипотеза. Chaos
engineering проверяет её контролируемыми экспериментами (убить под,
добавить задержку, нагрузить CPU), пока это не сделал продакшн в 3 часа
ночи.

## Пререквизиты
- [01_slo_sli_sla](../01_slo_sli_sla/) — «устойчивое состояние»
  эксперимента формулируется через SLI.
- [4_kubernetes/02_workloads](../../4_kubernetes/02_workloads/) —
  Deployment, ReplicaSet, probes.
- [0_lab_setup/03_local_k8s](../../0_lab_setup/03_local_k8s/) —
  локальный кластер kind/k3d.
- [4_kubernetes/07_manifests_management](../../4_kubernetes/07_manifests_management/)
  — Helm, которым ставится LitmusChaos.

## Файлы
- [01_theory/chaos_engineering.md](./01_theory/chaos_engineering.md) —
  принципы (гипотеза, blast radius), что тестировать, LitmusChaos,
  простые эксперименты на `kubectl`.
- [02_examples/litmus-pod-delete.yaml](./02_examples/litmus-pod-delete.yaml)
  — `ChaosEngine` с экспериментом pod-delete и HTTP-пробой.

Отдельных упражнений нет: эксперимент из `02_examples/` выполняется в
локальном кластере (🖥 Tier 2) после установки LitmusChaos, как описано
в теории; простые эксперименты без Litmus — там же.

## Как проходить
1. Прочитать теорию.
2. В kind-кластере развернуть nginx с 3 репликами и выполнить простой
   эксперимент: `kubectl delete pod -l app=nginx` и наблюдать за
   восстановлением.
3. По желанию — установить LitmusChaos и применить
   `litmus-pod-delete.yaml` (манифесту нужны CRD Litmus и service
   account эксперимента; детали — в теории и документации Litmus).

## Когда двигаться дальше
- Можете сформулировать эксперимент как гипотезу со steady state,
  blast radius и критерием остановки.
- Можете объяснить, почему начинают со staging и gameday, а не с
  продакшна.

Дальше — [07_capacity_planning](../07_capacity_planning/).
