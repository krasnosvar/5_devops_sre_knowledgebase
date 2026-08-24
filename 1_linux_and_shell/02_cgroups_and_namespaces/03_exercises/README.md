# Упражнения — cgroups и namespaces

Требуется: Linux с root доступом или sudo. Часть упражнений — в Docker.

## 01 — PID namespace: свой PID 1

```bash
# unshare — запустить процесс в новом namespace
sudo unshare --pid --fork --mount-proc bash

# Внутри нового namespace:
echo "My PID: $$"   # должен быть 1 или маленькое число
ps aux               # видит только свои процессы
echo "Process count: $(ps aux | wc -l)"

exit   # вернуться в исходный namespace
```

## 02 — Проверить namespaces контейнера

```bash
# Запустить контейнер
docker run -d --name ns-demo nginx:alpine

# Найти PID главного процесса
CONTAINER_PID=$(docker inspect ns-demo --format '{{.State.Pid}}')
echo "Container main PID on host: $CONTAINER_PID"

# Посмотреть namespaces
ls -la /proc/$CONTAINER_PID/ns/

# Войти в network namespace контейнера
sudo nsenter --net -t $CONTAINER_PID ip addr show
# должны быть интерфейсы контейнера (eth0, lo)

docker rm -f ns-demo
```

## 03 — cgroups v2: ограничить память процесса

```bash
# Проверить cgroups v2
mount | grep cgroup2

# Создать cgroup
sudo mkdir /sys/fs/cgroup/mytest

# Установить лимит 50 MB
echo "52428800" | sudo tee /sys/fs/cgroup/mytest/memory.max

# Запустить процесс в этом cgroup
# (нужен bash >= 5.1 для cgroup delegation)
sudo cgexec -g memory:mytest python3 -c "
import time
data = []
for i in range(100):
    data.append(b'x' * 1024 * 1024)  # 1 MB за раз
    print(f'Allocated {i+1} MB')
    time.sleep(0.1)
"
# Процесс должен быть убит OOM killer после ~50 MB

# Проверить
sudo cat /sys/fs/cgroup/mytest/memory.events | grep oom
sudo rmdir /sys/fs/cgroup/mytest
```

## 04 — Связь с k8s resource limits

```bash
# Запустить kind кластер
kind create cluster --name cgroup-demo

# Создать pod с memory limit
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: memory-demo
spec:
  containers:
    - name: app
      image: python:3.12-slim
      resources:
        limits:
          memory: "64Mi"
      command: ["python3", "-c", "
import time
data = []
while True:
    data.append(b'x' * 1024 * 1024)
    print(f'Allocated {len(data)} MB')
    time.sleep(0.5)
"]
EOF

# Наблюдать как k8s убивает Pod при OOMKill
kubectl get pod memory-demo -w

# Проверить причину
kubectl describe pod memory-demo | grep -A 5 "Last State"

kind delete cluster --name cgroup-demo
```
