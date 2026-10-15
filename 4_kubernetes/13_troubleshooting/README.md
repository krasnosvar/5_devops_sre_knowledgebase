# 13. Траблшутинг Kubernetes

## Зачем
Инцидент в Kubernetes редко выглядит как понятная ошибка: под в
`CrashLoopBackOff` с пустыми логами, `Pending` при свободных CPU,
`NotReady` нода с `PLEG is not healthy`, спорадические 502 от
Ingress, DNS-таймауты ровно по 5 секунд. Тема собирает системный
порядок диагностики по слоям: под → планировщик → нода → сеть → L7, и
инструменты для контейнеров без shell.

## Пререквизиты
- [02_workloads](../02_workloads/) — probes и жизненный цикл пода.
- [03_networking](../03_networking/) — Service, EndpointSlice,
  kube-proxy, CoreDNS, Ingress.
- [05_scheduling](../05_scheduling/) — фильтрация/скоринг, taints,
  affinity.
- [08_cluster_operations/01_core](../08_cluster_operations/01_core/) —
  базовое чтение статусов подов.
- [1_linux_and_shell](../../1_linux_and_shell/) — cgroups, сигналы,
  `journalctl`: на ноде без них не разобраться.

## Файлы
- [01_theory/kubernetes_troubleshooting.md](./01_theory/kubernetes_troubleshooting.md)
  — CrashLoopBackOff и exit codes, OOMKilled (cgroups v1/v2), probes,
  Pending, NotReady/PLEG/eviction, Service и `ndots:5`, 502/504 на
  Ingress, `kubectl debug` и ephemeral containers, `crictl`.

Без отдельных упражнений: сценарии поломок воспроизводятся на kind по
ходу чтения (пример: под с лимитом памяти меньше потребления даёт
OOMKilled, неверный селектор Service — пустой EndpointSlice). Отработка
на kubeadm-кластере (нода, PLEG, kubelet) — 🖥 Tier 2.

## Как проходить
1. Теория по разделам; каждую команду из теории выполнить на своём
   кластере.
2. Для каждого раздела самому сломать что-то на kind (неверный образ,
   лимит памяти, селектор, NetworkPolicy deny) и найти причину только
   командами из теории.
3. Interview Q&A в конце — ответить без подсказки.

## Когда двигаться дальше
- По статусу пода сразу знаете первый шаг диагностики.
- Можете объяснить путь запроса client → DNS → kube-proxy →
  EndpointSlice → CNI → pod и где что проверять.
- Знаете, откуда берутся 502 при keep-alive mismatch и 5-секундные
  DNS-задержки.
- Умеете отладить distroless-контейнер через `kubectl debug --target`.

Дальше — [5_iac](../../5_iac/): описание кластеров и инфраструктуры
кодом.
