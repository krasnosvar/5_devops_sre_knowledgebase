# 05. Планирование подов (Scheduling)

## Зачем
Куда попадёт под, переживёт ли сервис падение зоны, кого выселят при
нехватке памяти и не "съест" ли одна команда весь кластер — всё это
задаётся правилами планирования. Тема даёт инструменты управления
размещением и защиту от вытеснения.

## Пререквизиты
- [01_architecture](../01_architecture/) — как работает kube-scheduler
  (filtering и scoring).
- [02_workloads](../02_workloads/) — Deployment, DaemonSet, QoS-классы
  встречались в упражнении 05.

## Файлы
- [01_theory/scheduling.md](./01_theory/scheduling.md) — nodeSelector и
  node affinity, taints и tolerations, topology spread constraints,
  PodDisruptionBudget, QoS-классы, ResourceQuota и LimitRange.
- [02_examples/scheduling-demo.yaml](./02_examples/scheduling-demo.yaml)
  — Deployment с affinity и tolerations, PDB и др.
- Упражнений нет: эффект taints/affinity виден только на нескольких
  нодах — примените пример на многонодовом kind-кластере
  ([0_lab_setup/03_local_k8s](../../0_lab_setup/03_local_k8s/)) и
  проверьте размещение через `kubectl get pods -o wide`.

## Как проходить
1. Прочитать теорию.
2. Поднять kind из 1 control-plane и 2 worker-нод, повесить на одну
   ноду label/taint и применить пример.
3. Убедиться, что поды легли туда, куда ожидали; сверить с Q&A.

## Когда двигаться дальше
- Можете объяснить разницу taints/tolerations и node affinity.
- Можете объяснить, почему PDB не защищает от падения ноды.
- По `resources` пода сразу называете его QoS-класс.

Дальше — [06_security](../06_security/).
