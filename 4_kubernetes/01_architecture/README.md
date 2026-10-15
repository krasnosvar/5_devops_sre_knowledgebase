# 01. Архитектура Kubernetes

## Зачем
Почти любой инцидент в Kubernetes упирается в вопрос "какой компонент
не сделал свою работу": под завис в Pending (scheduler), не стартует
(kubelet, runtime), объект не создаётся (apiserver, admission), кластер
"застыл" (etcd). Тема даёт карту control plane и data plane, чтобы
диагностировать по цепочке, а не наугад.

## Пререквизиты
- [00_first_steps](../00_first_steps/) — kubectl, Pod/Deployment/Service,
  локальный кластер.
- [3_containers](../../3_containers/) — что такое container runtime,
  namespaces и cgroups.

## Файлы
- [01_theory/k8s_architecture.md](./01_theory/k8s_architecture.md) —
  компоненты control plane, kube-controller-manager и его контроллеры,
  etcd (Raft, MVCC), фазы обработки запроса в apiserver, scheduler,
  kubelet и PLEG, способы поднять кластер. Разделы про Raft/MVCC и
  PLEG помечены как необязательные при первом чтении.
- [02_examples/trace-pod-creation.sh](./02_examples/trace-pod-creation.sh)
  — создаёт под и показывает его путь через scheduler и kubelet по
  Events и статусу (нужны kind и jq).
- Упражнений нет: архитектуру закрепляют упражнения следующих тем, а
  трассировку можно повторить скриптом из примеров.

## Как проходить
1. Прочитать §1-2 и §4-5 теории; §3 (etcd) и разбор PLEG в §6 при
   первом чтении можно пролистать.
2. Запустить `trace-pod-creation.sh` на kind-кластере и сопоставить
   Events с компонентами из теории.
3. Ответить себе на Q&A в конце теории, затем свериться с ответами.

## Когда двигаться дальше
- Можете перечислить, через какие компоненты проходит `kubectl apply`
  до запущенного контейнера.
- Можете объяснить, что продолжит работать при падении etcd или
  apiserver, а что — нет.
- По статусу пода (Pending, ContainerCreating, CrashLoopBackOff) сразу
  называете компонент, который смотреть первым.

Дальше — [02_workloads](../02_workloads/).
