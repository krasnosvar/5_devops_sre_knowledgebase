# Scheduling — размещение Pod'ов по нодам

## Как работает kube-scheduler

```
Filtering (отсев непригодных нод)
    nodeSelector / Node Affinity не совпадают → исключить
    Недостаточно ресурсов (requests > available) → исключить
    Taint без Toleration → исключить
    PVC не может быть смонтирован на этой ноде → исключить
          │
          ▼ оставшиеся ноды
Scoring (оценка пригодных нод)
    LeastAllocated: предпочитать менее загруженные
    InterPodAffinity: предпочитать ноды где уже есть нужные поды
    TopologySpreadConstraints: равномерное распределение
          │
          ▼ нода с максимальным score
Binding: записать spec.nodeName в Pod
```

## nodeSelector — простой выбор ноды

```yaml
spec:
  nodeSelector:
    kubernetes.io/os: linux
    node-type: gpu             # ваш custom label
```

```bash
# добавить label на ноду
kubectl label node worker-1 node-type=gpu
kubectl label node worker-1 topology.kubernetes.io/zone=eu-central-1a
```

## Node Affinity — гибкий выбор

```yaml
spec:
  affinity:
    nodeAffinity:
      # жёсткое требование (scheduler не разместит если не выполняется)
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: kubernetes.io/arch
                operator: In
                values: [amd64, arm64]

      # мягкое предпочтение (постарается разместить)
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          preference:
            matchExpressions:
              - key: node-type
                operator: In
                values: [ssd]
```

## Pod Anti-Affinity — разнести Pod'ы по нодам

```yaml
spec:
  affinity:
    podAntiAffinity:
      # жёсткое: не ставить два pod с app=api на одну ноду
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              app: api
          topologyKey: kubernetes.io/hostname

      # мягкое: предпочитать разные AZ
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchLabels:
                app: api
            topologyKey: topology.kubernetes.io/zone
```

## Taints и Tolerations

**Taint** на ноде — «не ставь сюда pod если нет toleration».
**Toleration** в Pod — «я согласен работать на нодах с этим taint».

```bash
# добавить taint на ноду
kubectl taint node gpu-node gpu=true:NoSchedule
kubectl taint node gpu-node gpu=true:NoExecute     # выселит существующие pods
kubectl taint node gpu-node gpu=true:PreferNoSchedule  # мягкое

# убрать taint
kubectl taint node gpu-node gpu=true:NoSchedule-
```

```yaml
# toleration в Pod
spec:
  tolerations:
    - key: gpu
      operator: Equal
      value: "true"
      effect: NoSchedule

    # k8s автоматически добавляет toleration для node-ready (важно для DaemonSet):
    - key: node.kubernetes.io/not-ready
      operator: Exists
      effect: NoExecute
      tolerationSeconds: 300
```

## TopologySpreadConstraints — равномерное распределение

```yaml
spec:
  topologySpreadConstraints:
    # равномерно по зонам доступности
    - maxSkew: 1              # максимальная разница между зонами
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: DoNotSchedule   # или ScheduleAnyway
      labelSelector:
        matchLabels:
          app: myapp

    # равномерно по нодам
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: ScheduleAnyway
      labelSelector:
        matchLabels:
          app: myapp
```

## PodDisruptionBudget — защита от одновременного выселения

```yaml
# минимум 2 pod всегда доступны при node drain / rolling update
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: myapp-pdb
spec:
  minAvailable: 2          # или: maxUnavailable: 1
  selector:
    matchLabels:
      app: myapp
```

```bash
# drain ноды (уважает PDB — не выселит если нарушит minAvailable)
kubectl drain worker-1 --ignore-daemonsets --delete-emptydir-data

# cordon — запретить новые pod'ы (без выселения существующих)
kubectl cordon worker-1
kubectl uncordon worker-1
```

## Limits и Requests — влияние на scheduling

```yaml
resources:
  requests:
    cpu: "500m"       # планировщик использует это для размещения
    memory: "256Mi"   # нода считается "занятой" на этот объём
  limits:
    cpu: "1000m"      # throttling при превышении
    memory: "512Mi"   # OOMKill при превышении
```

```bash
# посмотреть allocatable ресурсы ноды
kubectl describe node worker-1 | grep -A 10 "Allocatable:"
kubectl describe node worker-1 | grep -A 10 "Allocated resources:"

# посмотреть resource requests всех pod'ов
kubectl top pod --all-namespaces
kubectl resource-capacity --sort cpu.request   # плагин kubectl-resource-capacity
```
