# 04. Хранилище в Kubernetes

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — команды и
> шаблоны одним экраном.

## Зачем
Поды эфемерны, а данные — нет. Тема о том, как Kubernetes подключает
диски к подам (PV, PVC, StorageClass, CSI), почему под с томом может
застрять в Pending из-за зоны доступности и как расширять тома и
делать снапшоты без остановки сервиса.

## Пререквизиты
- [02_workloads](../02_workloads/) — StatefulSet и volumeClaimTemplates.
- [3_containers/04_storage](../../3_containers/04_storage/) — тома и
  bind mount в контейнерах.

## Файлы
- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: PVC, StorageClass, снапшоты.
- [01_theory/k8s_storage.md](./01_theory/k8s_storage.md) — emptyDir и
  его лимиты, Local PV и local-path provisioner, topology-aware
  provisioning, volume expansion, CSI snapshots и клонирование.
- [02_examples/storage-demo.yaml](./02_examples/storage-demo.yaml) —
  StorageClass, PVC и под, использующий том.
- Упражнений нет: базовый сценарий (PVC переживает пересоздание пода)
  отрабатывается в упражнении 02
  [02_workloads](../02_workloads/03_exercises/README.md); снапшоты и
  topology требуют облачного CSI-драйвера.

## Как проходить
1. Прочитать теорию.
2. Применить `storage-demo.yaml` на kind (там есть StorageClass
   `standard` на базе local-path) и посмотреть `kubectl get pv,pvc`.
3. Ответить на Q&A в конце теории.

## Когда двигаться дальше
- Можете объяснить цепочку PVC → StorageClass → CSI → PV и кто её
  создаёт при динамическом провижининге.
- Можете объяснить, почему `WaitForFirstConsumer` решает проблему зон.
- Знаете, что делать с томом RWO, который "застрял" на мёртвой ноде.

Дальше — [05_scheduling](../05_scheduling/).
