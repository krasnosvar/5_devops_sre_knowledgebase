# Хранилище в Kubernetes — шпаргалка

Подробности и объяснения — в
[k8s_storage.md](./01_theory/k8s_storage.md). ⚠️ — опасная команда или
частая ловушка.

## Какой том выбрать

| Задача | Том |
| :--- | :--- |
| Обмен файлами между контейнерами пода, кэш | `emptyDir` (+ `sizeLimit`) |
| Быстрый RAM-диск (секреты, кэш) | `emptyDir.medium: Memory` (считается в memory limit) |
| Данные, переживающие под | PVC → PV (динамически через StorageClass) |
| Максимум IOPS, локальный NVMe | Local PV (`nodeAffinity`), local-path-provisioner |
| Много подов на разных нодах пишут в один том | RWX: NFS, CephFS, EFS |
| Конфиги и секреты | `configMap` / `secret` / `projected` |
| Папка хоста ⚠️ | `hostPath` — scheduler о ней не знает, риск побега на хост |

| accessModes | Смысл |
| :--- | :--- |
| `ReadWriteOnce` (RWO) | одна **нода** (поды на ней — все) |
| `ReadWriteOncePod` (RWOP) | ровно один под |
| `ReadOnlyMany` (ROX) | много нод, только чтение |
| `ReadWriteMany` (RWX) | много нод, чтение и запись (сетевые ФС) |

## StorageClass

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: db-ssd
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer   # диск в зоне выбранной ноды
reclaimPolicy: Retain                     # delete PVC не удалит диск
allowVolumeExpansion: true
parameters:
  type: gp3
```

| Поле | По умолчанию | Для БД |
| :--- | :--- | :--- |
| `volumeBindingMode` | `Immediate` | `WaitForFirstConsumer` |
| `reclaimPolicy` | `Delete` | `Retain` |
| `allowVolumeExpansion` | `false` | `true` |

## Команды

| Задача | Команда |
| :--- | :--- |
| Классы, default-класс помечен `(default)` | `kubectl get storageclass` |
| PVC и к какому PV привязан | `kubectl get pvc -A` |
| PV, статус, reclaim policy | `kubectl get pv` |
| Почему PVC в `Pending` | `kubectl describe pvc data-db-0` → Events |
| Какие поды используют PVC | `kubectl describe pvc data-db-0` → `Used By` |
| Подключения дисков к нодам (CSI) | `kubectl get volumeattachment` |
| CSI-драйверы кластера | `kubectl get csidriver` |
| Расширить PVC | `kubectl patch pvc data-db-0 -p '{"spec":{"resources":{"requests":{"storage":"200Gi"}}}}'` |
| Статус расширения | `kubectl get pvc data-db-0 -o jsonpath='{.status.conditions}'` |
| Сменить reclaim policy у PV | `kubectl patch pv <pv> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'` |
| Освободить `Released` PV для повторной привязки ⚠️ | `kubectl patch pv <pv> --type=json -p '[{"op":"remove","path":"/spec/claimRef"}]'` |
| Сделать класс default | `kubectl annotate sc db-ssd storageclass.kubernetes.io/is-default-class=true` |
| Место в томе изнутри | `kubectl exec db-0 -- df -h /var/lib/postgresql/data` |
| Снапшоты | `kubectl get volumesnapshot,volumesnapshotcontent,volumesnapshotclass` |

## Снапшот и клон

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata: {name: db-snap}
spec:
  volumeSnapshotClassName: csi-snapclass
  source: {persistentVolumeClaimName: data-db-0}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: db-restore}
spec:
  storageClassName: db-ssd
  accessModes: [ReadWriteOnce]
  resources: {requests: {storage: 100Gi}}
  dataSource:              # клон: kind: PersistentVolumeClaim, name: <pvc>
    apiGroup: snapshot.storage.k8s.io
    kind: VolumeSnapshot
    name: db-snap
```

## Жизненный цикл PV

| Статус | Значит |
| :--- | :--- |
| `Available` | свободен |
| `Bound` | привязан к PVC |
| `Released` | PVC удалён, PV с `Retain` ждёт админа (снова не привяжется сам) |
| `Failed` | ошибка автоматического reclaim |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| PVC `Pending` | нет default StorageClass, `WaitForFirstConsumer` ждёт под, ошибка provisioner в Events |
| Под `ContainerCreating`, `Multi-Attach error` | RWO-диск ещё прикреплён к другой ноде → `volumeattachment` |
| `FailedMount ... exclusively attached` после падения ноды | облако не сделало detach → force detach |
| Под `Pending`: `volume node affinity conflict` | зональный диск в другой AZ, Local PV на другой ноде |
| После resize `df` показывает старый размер | вторая фаза (ФС) не прошла → `FileSystemResizePending`, пересоздать под |
| Под выселен, `ephemeral-storage` | `emptyDir` / логи забили диск ноды → `sizeLimit`, `resources.limits.ephemeral-storage` |
| PVC завис в `Terminating` | finalizer `kubernetes.io/pvc-protection`: под ещё использует PVC |

## Ловушки

- ⚠️ `reclaimPolicy: Delete` + `kubectl delete pvc` = удалён облачный диск.
- ⚠️ `Immediate` binding в мульти-AZ: диск в одной зоне, под в другой.
- ⚠️ Scale down StatefulSet оставляет PVC — при scale up под получит
  старые данные.
- Превышение `sizeLimit` у `emptyDir` — eviction пода (не рестарт
  контейнера), данные `emptyDir` теряются.
- Уменьшить PVC нельзя — только расширять.

> Проверка: команды сверены с `kubectl <cmd> --help` (v1.34.1);
> StorageClass/PVC, `get sc`, `describe pvc`, patch PV на
> local-path-provisioner временного kind-кластера; не проверено:
> VolumeSnapshot (нет CRD снапшотов в kind), resize, EBS CSI.
