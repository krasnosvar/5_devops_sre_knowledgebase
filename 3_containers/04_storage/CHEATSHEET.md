# Хранение данных контейнеров — шпаргалка

Подробности и объяснения — в
[container_storage.md](./01_theory/container_storage.md).
⚠️ — опасная команда или частая ловушка.

## Docker: что выбрать

| Тип | Синтаксис | Где данные | Когда |
| :--- | :--- | :--- | :--- |
| Named volume | `-v pgdata:/var/lib/postgresql/data` | `/var/lib/docker/volumes/` | данные БД, best practice |
| Bind mount | `-v /opt/conf:/etc/app:ro` | путь хоста | конфиги, код в dev |
| tmpfs | `--tmpfs /app/cache` | RAM | секреты, временный кэш |
| writable-слой | — | `UpperDir` overlay | ничего ценного: CoW и исчезает с контейнером |

## Команды Docker

| Задача | Команда |
| :--- | :--- |
| Создать / список томов | `docker volume create pgdata` / `docker volume ls` |
| Где лежит том | `docker volume inspect -f '{{.Mountpoint}}' pgdata` |
| Монтирования контейнера | `docker inspect -f '{{json .Mounts}}' <c>` |
| Явный синтаксис `--mount` | `--mount type=volume,src=pgdata,dst=/data`<br>`--mount type=bind,src=$(pwd)/conf,dst=/etc/app,readonly` |
| tmpfs с ограничением | `--mount type=tmpfs,dst=/app/cache,tmpfs-size=64m` |
| Бэкап тома в tar | `docker run --rm -v pgdata:/source:ro -v "$(pwd)":/backup alpine tar czf /backup/pgdata.tgz -C /source .` |
| Восстановить | `docker run --rm -v pgdata:/target -v "$(pwd)":/backup:ro alpine tar xzf /backup/pgdata.tgz -C /target` |
| Удалить неиспользуемые тома ⚠️ | `docker volume prune` (с `-a` — и именованные) |

## Kubernetes: PV / PVC / StorageClass

| Объект | Кто создаёт | Роль |
| :--- | :--- | :--- |
| StorageClass | админ | шаблон: CSI-драйвер, параметры, `reclaimPolicy` |
| PVC | разработчик, в namespace | заявка: размер + accessMode + class |
| PV | админ или dynamic provisioning | конкретный диск, кластерный объект |
| CSI | вендор (controller + node DaemonSet) | Provision → Attach → Mount |

| Access mode | Смысл | Типично |
| :--- | :--- | :--- |
| `ReadWriteOnce` (RWO) | RW с одной **ноды** | блочные: EBS, облачные диски |
| `ReadWriteOncePod` (RWOP) | RW только одним подом | строгая эксклюзивность |
| `ReadWriteMany` (RWX) | RW со многих нод | NFS, CephFS |
| `ReadOnlyMany` (ROX) | только чтение многими | общие данные |

| `reclaimPolicy` | После удаления PVC |
| :--- | :--- |
| `Delete` (default для dynamic) | PV и облачный диск удаляются ⚠️ |
| `Retain` | PV → `Released`, диск остаётся (и тарифицируется) |

## kubectl

| Задача | Команда |
| :--- | :--- |
| Классы и default | `kubectl get storageclass` |
| Заявки и их статус | `kubectl get pvc -A` |
| Почему PVC в `Pending` | `kubectl describe pvc <name>` (Events) |
| Тома и к чему привязаны | `kubectl get pv` |
| Attach дисков к нодам | `kubectl get volumeattachments` |
| Сменить политику PV на Retain | `kubectl patch pv <pv> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'` |

## Шаблон PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 10Gi
```

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| Deployment на 3 реплики с одним RWO PVC: 2 пода в `ContainerCreating` | `Multi-Attach error` в Events — нужен StatefulSet с `volumeClaimTemplates` или RWX |
| PVC `Pending` | нет default StorageClass, `WaitForFirstConsumer`, ошибка CSI |
| `Permission denied` у БД на томе | владелец root — `securityContext.fsGroup` или init-контейнер с `chown` |
| Данные исчезли после пересоздания контейнера | писали в writable-слой, а не в volume |
| Удалили PVC — диск в облаке остался | `reclaimPolicy: Retain` — удалить PV и диск вручную |

## Подвохи

| ⚠️ | Суть |
| :--- | :--- |
| `-v /var/run/docker.sock:...` | равносильно root на хосте |
| tmpfs для основной БД | данные теряются при рестарте |
| Bind mount и UID | UID в контейнере ≠ владелец каталога на хосте |

> Проверка: команды `docker volume`/`--mount`/бэкап-tar выполнены
> локально (Docker 29.9), YAML — `yamllint` и `kubeconform -strict`
> (v0.7.0, в контейнере); не проверено: kubectl против кластера,
> поведение CSI.
