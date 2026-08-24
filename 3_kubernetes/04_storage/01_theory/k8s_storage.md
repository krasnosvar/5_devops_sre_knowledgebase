# Kubernetes Storage

## PersistentVolume / PersistentVolumeClaim / StorageClass

```
StorageClass → описывает тип хранилища и provisioner
PersistentVolume (PV) → реальный том (создаётся provisioner'ом или вручную)
PersistentVolumeClaim (PVC) → запрос на хранилище от Pod'а
```

```yaml
# StorageClass — описывает как создавать тома
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com     # AWS EBS CSI driver
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
reclaimPolicy: Delete             # Delete или Retain
volumeBindingMode: WaitForFirstConsumer  # создать том в той же AZ что и Pod
allowVolumeExpansion: true        # разрешить увеличение тома
```

```yaml
# PVC — запрос Pod'а на хранилище
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data
  namespace: production
spec:
  accessModes: [ReadWriteOnce]   # только один Pod может монтировать
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 50Gi
```

```yaml
# Pod использует PVC
spec:
  containers:
    - name: postgres
      image: postgres:16
      volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: postgres-data
```

## Access Modes

| Mode | Сокращение | Что означает |
|------|-----------|-------------|
| ReadWriteOnce | RWO | Один Node может монтировать R/W |
| ReadOnlyMany | ROX | Много Node'ов — только чтение |
| ReadWriteMany | RWX | Много Node'ов — чтение и запись (NFS, EFS, CephFS) |
| ReadWriteOncePod | RWOP | Только один Pod (k8s 1.29+) |

## Reclaim Policy

**Delete** — при удалении PVC удаляется и PV (и данные). Для временных окружений.
**Retain** — при удалении PVC данные остаются. Нужно вручную удалить PV. Для production.

```bash
# посмотреть что происходит с PV при удалении PVC
kubectl get pv
kubectl describe pv pvc-abc123 | grep "Reclaim Policy"
```

## CSI — Container Storage Interface

CSI — стандарт для storage плагинов. Provisioner создаёт PV автоматически при создании PVC.

Популярные CSI drivers:
- `ebs.csi.aws.com` — AWS EBS
- `efs.csi.aws.com` — AWS EFS (RWX)
- `disk.csi.azure.com` — Azure Disk
- `pd.csi.storage.gke.io` — GCP Persistent Disk
- `rook-ceph.rbd.csi.ceph.com` — Ceph RBD
- `smb.csi.k8s.io` — SMB/NFS

## StatefulSet + volumeClaimTemplates

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres
  replicas: 3
  selector:
    matchLabels:
      app: postgres
  template:
    spec:
      containers:
        - name: postgres
          image: postgres:16
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:       # создаётся автоматически для каждого Pod
    - metadata:
        name: data
      spec:
        accessModes: [ReadWriteOnce]
        storageClassName: fast-ssd
        resources:
          requests:
            storage: 100Gi
# Создаст PVC: data-postgres-0, data-postgres-1, data-postgres-2
```

## Расширение тома

```bash
# 1. Убедиться что StorageClass разрешает расширение
kubectl get sc fast-ssd -o jsonpath='{.allowVolumeExpansion}'

# 2. Увеличить запрос в PVC
kubectl patch pvc postgres-data \
  -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}'

# 3. Дождаться расширения
kubectl get pvc postgres-data -w
# ConditionType=FileSystemResizePending → Resizing → готово

# Для файловых систем требует перезапуска Pod (или live resize если поддерживается)
```

## Ephemeral volumes

```yaml
spec:
  volumes:
    # emptyDir — создаётся при запуске Pod, удаляется при остановке
    - name: cache
      emptyDir:
        sizeLimit: 500Mi

    # emptyDir в памяти
    - name: secrets-store
      emptyDir:
        medium: Memory
        sizeLimit: 10Mi

    # projected — комбинация из ConfigMap, Secret, ServiceAccount token
    - name: config
      projected:
        sources:
          - configMap:
              name: app-config
          - secret:
              name: app-secrets
```

## Полезные команды

```bash
kubectl get pv,pvc -A
kubectl get pvc -n production
kubectl describe pvc mydata -n production
kubectl get storageclass

# найти PVC которые не используются (нет Pod'а)
kubectl get pvc -A -o json | jq '
  .items[] |
  select(.status.phase != "Bound") |
  {name: .metadata.name, ns: .metadata.namespace, phase: .status.phase}
'
```
