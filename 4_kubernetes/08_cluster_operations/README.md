# 08. Эксплуатация кластера

## Зачем
Кластер мало поднять — его надо обслуживать: выводить ноды на ремонт
без даунтайма, обновлять версии Kubernetes по правилам version skew,
бэкапить etcd и приложения, не пропустить истечение сертификатов и
добавлять ноды, когда подам некуда встать. Это ежедневная работа SRE
на "Day-2", и именно здесь чаще всего случаются аварии по
неосторожности.

## Пререквизиты
- [01_architecture](../01_architecture/) — control plane, etcd,
  kubelet, static pods.
- [05_scheduling](../05_scheduling/) — taints/tolerations,
  PodDisruptionBudget, `requests`: на них опираются drain и
  автоскейлинг нод.
- [02_workloads](../02_workloads/) — ReplicaSet/DaemonSet: кто
  пересоздаёт поды после drain.

## Файлы
Тема разбита на две подтемы:
- [01_core/](./01_core/) — cordon/drain, обновление кластера
  (kubeadm, version skew), etcd snapshot и Velero, ротация
  сертификатов, чтение статусов подов; пример — скрипт быстрой
  диагностики `troubleshoot.sh`.
- [02_node_autoscaling/](./02_node_autoscaling/) — Cluster Autoscaler
  vs Karpenter, Consolidation.

Упражнений нет: drain/upgrade/etcd-restore осмысленно отрабатывать на
kubeadm-кластере из нескольких VM (🖥 Tier 2), а автоскейлинг нод —
только в реальном облаке (☁️ Tier 3). Минимальная практика на kind:
`kubectl cordon`/`drain` на worker-ноде кластера из
[00_first_steps](../00_first_steps/).

## Как проходить
1. [01_core](./01_core/): теория, затем прогнать
   `02_examples/troubleshoot.sh` на своём kind-кластере.
2. [02_node_autoscaling](./02_node_autoscaling/): теория.
3. Ответить на Interview Q&A в конце каждой теории, не подглядывая.

## Когда двигаться дальше
- Можете объяснить, почему `drain` зависает на PodDisruptionBudget и
  что с этим делать.
- Знаете порядок обновления kubeadm-кластера на две минорные версии.
- Можете объяснить разницу etcd snapshot и Velero и когда нужен
  каждый.
- Понимаете, почему Cluster Autoscaler реагирует на `Pending`, а не на
  загрузку CPU.

Дальше — [09_gitops](../09_gitops/).
