# 08.1. Эксплуатация кластера: основы

## Зачем
Безопасный вывод ноды на обслуживание, обновление версии кластера,
бэкап и восстановление, ротация сертификатов и первичный разбор
"под не стартует" — базовый набор операций, без которого кластер
нельзя считать production-ready.

## Пререквизиты
- [01_architecture](../../01_architecture/) — static pods, etcd.
- [05_scheduling](../../05_scheduling/) — PDB, taints.

## Файлы
- [01_theory/cluster_operations.md](./01_theory/cluster_operations.md)
  — cordon/drain и Eviction API, upgrade через kubeadm и version skew,
  etcd snapshot vs Velero, автоскейлинг нод (кратко), сертификаты
  kubeadm, CrashLoopBackOff/OOMKilled/Pending/ImagePullBackOff.
- [02_examples/troubleshoot.sh](./02_examples/troubleshoot.sh) —
  скрипт быстрого обзора кластера (ноды, проблемные поды, события) и
  helper-функции `debug_pod`, `logs_by_label`, `exec_by_label`.

Без упражнений: upgrade и восстановление etcd требуют kubeadm-кластера
на VM (🖥 Tier 2). Подробная диагностика инцидентов — в
[13_troubleshooting](../../13_troubleshooting/).

## Как проходить
1. Теория.
2. Запустить `bash 02_examples/troubleshoot.sh` на kind-кластере и
   разобрать каждый блок вывода.
3. На kind с worker-нодой: `kubectl cordon`, `kubectl drain
   --ignore-daemonsets`, `kubectl uncordon` — посмотреть, куда уезжают
   поды.

## Когда двигаться дальше
- Можете объяснить, что делает `drain` и почему без
  `--ignore-daemonsets` он отказывается работать.
- Знаете, что сломается через год у kubeadm-кластера без ротации
  сертификатов.
- По статусу пода сразу знаете, смотреть `logs --previous` или
  `describe` → Events.

Дальше — [02_node_autoscaling](../02_node_autoscaling/).
