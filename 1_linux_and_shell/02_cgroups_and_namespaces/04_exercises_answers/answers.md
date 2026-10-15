# Ответы — cgroups и namespaces

Все примеры рассчитаны на хост с cgroups v2 (`stat -fc %T /sys/fs/cgroup/`
печатает `cgroup2fs`). Выводы ниже приблизительные: PID, адреса и числа
у вас будут другими.

## Упражнение 01 — PID namespace: свой PID 1

```bash
echo "Host PID: $$, процессов: $(ps aux | wc -l)"

sudo unshare --pid --fork --mount-proc bash
echo "My PID: $$"
ps aux
exit
```

Ожидаемый вывод (примерно так):

```text
Host PID: 41872, процессов: 312
My PID: 1
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root           1  0.0  0.0   8740  5120 pts/3    S    10:12   0:00 bash
root           8  0.0  0.0  10884  4224 pts/3    R+   10:12   0:00 ps aux
```

Почему так: `--pid` создаёт новый PID namespace, `--fork` нужен, потому что
сам `unshare` в него не попадает — первым процессом namespace (PID 1)
становится его потомок `bash`. `--mount-proc` монтирует свежий `/proc`,
иначе `ps` читал бы `/proc` хоста и показывал бы все процессы.

## Упражнение 02 — Проверить namespaces контейнера

```bash
docker run -d --name ns-demo nginx:alpine
CONTAINER_PID=$(docker inspect ns-demo --format '{{.State.Pid}}')
echo "Container main PID on host: $CONTAINER_PID"

sudo ls -la /proc/$CONTAINER_PID/ns/
# Сравнить со своим shell: разные inode = разные namespaces
ls -la /proc/$$/ns/ | grep -E ' (net|pid|mnt) '

sudo nsenter --net -t $CONTAINER_PID ip addr show
docker rm -f ns-demo
```

Ожидаемый вывод (примерно так):

```text
Container main PID on host: 52310
lrwxrwxrwx 1 root root 0 ... mnt -> 'mnt:[4026533021]'
lrwxrwxrwx 1 root root 0 ... net -> 'net:[4026533024]'
lrwxrwxrwx 1 root root 0 ... pid -> 'pid:[4026533023]'
...
lrwxrwxrwx 1 den den 0 ... mnt -> 'mnt:[4026531841]'
lrwxrwxrwx 1 den den 0 ... net -> 'net:[4026531840]'
lrwxrwxrwx 1 den den 0 ... pid -> 'pid:[4026531836]'
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 ...
    inet 127.0.0.1/8 scope host lo
2: eth0@if87: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 ...
    inet 172.17.0.2/16 brd 172.17.255.255 scope global eth0
```

Почему так: каждый namespace — объект ядра со своим inode; одинаковое число
в `/proc/<pid>/ns/net` у двух процессов значит «одна сеть». `nsenter --net`
входит только в сетевой namespace контейнера, а файловая система остаётся
хостовой — поэтому работает `ip` хоста, даже если в образе его нет.
`eth0@if87` — один конец veth-пары, второй конец (индекс 87) живёт на хосте.

## Упражнение 03 — cgroups v2: ограничить память процесса

```bash
stat -fc %T /sys/fs/cgroup/                   # cgroup2fs
grep -w memory /sys/fs/cgroup/cgroup.subtree_control

sudo mkdir /sys/fs/cgroup/mytest
echo "52428800" | sudo tee /sys/fs/cgroup/mytest/memory.max
echo "0" | sudo tee /sys/fs/cgroup/mytest/memory.swap.max

cat > alloc.py <<'PY'
import time
data = []
for i in range(100):
    data.append(b'x' * 1024 * 1024)
    print(f'Allocated {i+1} MB', flush=True)
    time.sleep(0.1)
PY

sudo sh -c 'echo $$ > /sys/fs/cgroup/mytest/cgroup.procs && exec python3 alloc.py'
echo "exit code: $?"

sudo cat /sys/fs/cgroup/mytest/memory.events
sudo rmdir /sys/fs/cgroup/mytest
```

Ожидаемый вывод (примерно так):

```text
cgroup2fs
cpuset cpu io memory hugetlb pids rdma misc
52428800
0
Allocated 1 MB
...
Allocated 46 MB
Killed
exit code: 137
low 0
high 0
max 38
oom 1
oom_kill 1
```

Почему так: `memory.max` — жёсткий лимит v2 (в legacy v1 это был
`memory.limit_in_bytes`). Без `memory.swap.max=0` ядро могло бы выгружать
память в swap вместо OOM. Процесс убит SIGKILL, отсюда 128 + 9 = 137, а
`oom_kill 1` в `memory.events` доказывает, что убийца — OOM Killer этой
cgroup. `rmdir` срабатывает только когда в группе не осталось процессов.

## Упражнение 04 — Связь с k8s resource limits

```bash
kind create cluster --name cgroup-demo
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

kubectl get pod memory-demo -w        # Ctrl+C после пары рестартов
kubectl describe pod memory-demo | grep -A 5 "Last State"

# Где лимит лежит физически: нода kind — это Docker-контейнер
docker exec cgroup-demo-control-plane sh -c \
  "find /sys/fs/cgroup -path '*burstable*' -name memory.max \
     -exec grep -H 67108864 {} +"

kind delete cluster --name cgroup-demo
```

Ожидаемый вывод (примерно так):

```text
NAME          READY   STATUS              RESTARTS     AGE
memory-demo   0/1     ContainerCreating   0            2s
memory-demo   1/1     Running             0            10s
memory-demo   0/1     OOMKilled           0            40s
memory-demo   1/1     Running             1 (2s ago)   42s
memory-demo   0/1     OOMKilled           1 (32s ago)  72s
memory-demo   0/1     CrashLoopBackOff    1 (2s ago)   73s

    Last State:     Terminated
      Reason:       OOMKilled
      Exit Code:    137

/sys/fs/cgroup/.../kubelet-kubepods-burstable-pod<uid>.slice/memory.max:67108864
/sys/fs/cgroup/.../cri-containerd-<id>.scope/memory.max:67108864
```

Почему так: kubelet переводит `limits.memory: 64Mi` в `memory.max =
67108864` cgroup контейнера; убивает процесс не kubelet, а ядро (OOM Killer
cgroup), kubelet лишь видит код 137 и причину `OOMKilled`. Если `requests`
не заданы, они приравниваются к `limits`, но CPU не задан вовсе, поэтому
QoS-класс пода — Burstable, и cgroup лежит в ветке `...burstable...`.
Лимит стоит и на cgroup пода, и на cgroup контейнера.
