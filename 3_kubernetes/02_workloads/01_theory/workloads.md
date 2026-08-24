# Workloads — Pod, Deployment, StatefulSet, DaemonSet, Job

## Pod — минимальная единица развёртывания

Pod = один или несколько контейнеров + shared network namespace + shared volumes.
Контейнеры в Pod всегда на одной ноде, общают один IP, видят localhost друг друга.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  containers:
    - name: app
      image: nginx:alpine
      ports:
        - containerPort: 80
      resources:
        requests: { cpu: "100m", memory: "64Mi" }
        limits:   { cpu: "200m", memory: "128Mi" }
      readinessProbe:
        httpGet: { path: /health, port: 80 }
        initialDelaySeconds: 5
        periodSeconds: 10
      livenessProbe:
        httpGet: { path: /health, port: 80 }
        initialDelaySeconds: 15
        periodSeconds: 20
```

## Probes — как k8s определяет состояние Pod

**livenessProbe** — жив ли контейнер? При failure: restart.
**readinessProbe** — готов ли принимать трафик? При failure: убирают из Endpoints Service.
**startupProbe** — специально для медленно стартующих приложений. Пока не пройдёт — liveness не проверяется.

```
startupProbe успех → включается livenessProbe + readinessProbe
readinessProbe failure → Pod убирают из Service Endpoints (трафик не идёт)
livenessProbe failure → контейнер перезапускается (restart policy)
```

## Deployment — stateless приложения

Deployment управляет ReplicaSet, ReplicaSet управляет Pod.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # сколько Pod сверх replicas при обновлении
      maxUnavailable: 0  # сколько Pod можно отключить при обновлении
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: app
          image: myapp:1.0
```

```bash
# обновить образ
kubectl set image deployment/myapp app=myapp:2.0
# или: изменить в YAML и kubectl apply

# следить за rollout
kubectl rollout status deployment/myapp

# откатить
kubectl rollout undo deployment/myapp
kubectl rollout undo deployment/myapp --to-revision=2

# история
kubectl rollout history deployment/myapp
```

## StatefulSet — stateful приложения

Когда Pod нужна:
- стабильная сетевая идентичность (pod-0, pod-1, не случайные имена)
- стабильный storage (каждый Pod — свой PVC)
- упорядоченный запуск и остановка

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres-headless    # обязательно: headless service
  replicas: 3
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels: { app: postgres }
    spec:
      containers:
        - name: postgres
          image: postgres:16
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:             # отдельный PVC для каждого Pod
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 10Gi
```

Pods получают имена: `postgres-0`, `postgres-1`, `postgres-2`.
DNS: `postgres-0.postgres-headless.namespace.svc.cluster.local`

## DaemonSet — один Pod на каждую ноду

Используется для: node exporters, log collectors, CNI плагинов, агентов мониторинга.

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
spec:
  selector:
    matchLabels:
      app: node-exporter
  template:
    metadata:
      labels: { app: node-exporter }
    spec:
      tolerations:
        - key: node-role.kubernetes.io/control-plane   # запустить и на control plane
          effect: NoSchedule
          operator: Exists
      containers:
        - name: node-exporter
          image: prom/node-exporter
          ports:
            - containerPort: 9100
```

## Job и CronJob — разовые и периодические задачи

```yaml
# Job — запустить до успешного завершения
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migrate
spec:
  backoffLimit: 3            # попыток при failure
  completions: 1
  parallelism: 1
  template:
    spec:
      restartPolicy: OnFailure   # или: Never
      containers:
        - name: migrate
          image: myapp:2.0
          command: ["python", "manage.py", "migrate"]
```

```yaml
# CronJob — по расписанию
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup
spec:
  schedule: "0 2 * * *"      # каждую ночь в 02:00
  concurrencyPolicy: Forbid  # не запускать если предыдущий ещё идёт
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: backup
              image: backup-tool:latest
```

## QoS классы и eviction

При нехватке памяти на ноде kubelet выселяет Pod в порядке:
1. **BestEffort** (нет requests и limits) — первые
2. **Burstable** (limits > requests) — вторые
3. **Guaranteed** (limits == requests) — последние

```yaml
# Guaranteed QoS — одинаковые requests и limits
resources:
  requests: { cpu: "500m", memory: "256Mi" }
  limits:   { cpu: "500m", memory: "256Mi" }
```
