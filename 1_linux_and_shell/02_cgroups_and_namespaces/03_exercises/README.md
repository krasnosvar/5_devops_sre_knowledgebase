# Упражнения — cgroups и namespaces

Стенд: 🖥 Tier 2 — Linux VM с root/sudo и cgroups v2 (упражнения 01 и 03).
Упражнение 02 требует Docker, упражнение 04 — kind и kubectl.

> **Забегание вперёд.** Здесь используется Docker, который подробно
> разбирается в [3_containers](../../../3_containers/). Для этой темы
> достаточно: `docker run -d`, `docker inspect`, `docker rm -f`. Если Docker
> ещё не освоен — упражнение 02 можно пропустить и вернуться к нему позже.

> **Забегание вперёд.** Упражнение 04 использует kind (локальный
> Kubernetes-кластер в Docker, см.
> [0_lab_setup/03_local_k8s](../../../0_lab_setup/03_local_k8s/)) и kubectl
> (см. [4_kubernetes/00_first_steps](../../../4_kubernetes/00_first_steps/)).
> Для этой темы достаточно: `kind create/delete cluster`, `kubectl apply -f`,
> `kubectl get pod -w`, `kubectl describe pod`. Если Kubernetes ещё не
> освоен — упражнение 04 можно пропустить и вернуться к нему позже.

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
sudo ls -la /proc/$CONTAINER_PID/ns/   # чужой (root) процесс — нужен sudo

# Войти в network namespace контейнера
sudo nsenter --net -t $CONTAINER_PID ip addr show
# должны быть интерфейсы контейнера (eth0, lo)

docker rm -f ns-demo
```

## 03 — cgroups v2: ограничить память процесса

```bash
# Проверить cgroups v2
mount | grep cgroup2

# Создать cgroup (контроллер memory должен быть в
# /sys/fs/cgroup/cgroup.subtree_control — на systemd-хостах он там есть)
sudo mkdir /sys/fs/cgroup/mytest

# Установить лимит 50 MB и запретить swap, чтобы сработал именно OOM
echo "52428800" | sudo tee /sys/fs/cgroup/mytest/memory.max
echo "0" | sudo tee /sys/fs/cgroup/mytest/memory.swap.max

# Программа, которая съедает по 1 MB каждые 0.1 с
cat > alloc.py <<'PY'
import time
data = []
for i in range(100):
    data.append(b'x' * 1024 * 1024)  # 1 MB за раз
    print(f'Allocated {i+1} MB', flush=True)
    time.sleep(0.1)
PY

# Запустить процесс в этом cgroup: шелл переносит САМ СЕБЯ в группу
# (пишет свой PID в cgroup.procs), затем exec заменяет его на python3 —
# PID и cgroup при exec сохраняются
sudo sh -c 'echo $$ > /sys/fs/cgroup/mytest/cgroup.procs && exec python3 alloc.py'
# Процесс должен быть убит OOM killer после ~50 MB (shell напишет Killed)

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
      # Многострочный Python — через блочный скаляр YAML (|): строка
      # в кавычках склеила бы переводы строк в пробелы и сломала отступы
      command: ["python3", "-c"]
      args:
        - |
          import time
          data = []
          while True:
              data.append(b'x' * 1024 * 1024)
              print(f'Allocated {len(data)} MB', flush=True)
              time.sleep(0.5)
EOF

# Наблюдать как k8s убивает Pod при OOMKill
kubectl get pod memory-demo -w

# Проверить причину
kubectl describe pod memory-demo | grep -A 5 "Last State"

kind delete cluster --name cgroup-demo
```
