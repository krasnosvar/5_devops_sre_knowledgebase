# cgroups и namespaces — фундамент контейнеров

Контейнер — не отдельная технология. Это обычный Linux-процесс,
которому ядро ограничило ресурсы (cgroups) и изолировало представление
системы (namespaces).

## Namespaces — изоляция видимости

Namespace определяет, что процесс «видит» как свой мир:

| Namespace | Изолирует | Пример |
|-----------|-----------|--------|
| **PID** | Дерево процессов | Процесс видит себя как PID 1 |
| **NET** | Сетевые интерфейсы, маршруты | Свой lo, eth0, iptables |
| **MNT** | Файловая система (mount points) | Своя корневая ФС |
| **UTS** | Hostname и domainname | `hostname` возвращает имя контейнера |
| **IPC** | Shared memory, message queues | Изолированная межпроцессная коммуникация |
| **USER** | UID/GID mapping | root внутри = обычный юзер снаружи (rootless) |
| **NET** | Сеть | veth pair соединяет контейнер с хостом |

```bash
# посмотреть namespaces процесса
ls -la /proc/1234/ns/

# unshare — запустить в новом namespace (для экспериментов)
sudo unshare --pid --fork --mount-proc bash
# теперь PID 1 — наш bash, ps показывает только наши процессы

# nsenter — войти в namespace существующего процесса
sudo nsenter --pid --net --mount -t 1234 bash
# это буквально то, что делает `docker exec`
```

## cgroups — ограничение ресурсов

Control Groups — механизм ядра для группировки процессов и
применения ограничений на ресурсы.

### cgroups v1 vs v2

**v1** (устарел): каждый контроллер (cpu, memory, blkio) — отдельная иерархия.
**v2** (современный): единая иерархия, все контроллеры в одном дереве.
Linux 5.x+, Fedora 31+, Ubuntu 21.10+ используют v2 по умолчанию.

```bash
# проверить версию
mount | grep cgroup
stat -fc %T /sys/fs/cgroup   # "cgroup2fs" = v2, "tmpfs" = v1

# структура cgroups v2
ls /sys/fs/cgroup/
# system.slice/  user.slice/  machine.slice/  ...

# cgroup контейнера (docker)
ls /sys/fs/cgroup/system.slice/docker-<container-id>.scope/
cat /sys/fs/cgroup/system.slice/docker-<container-id>.scope/memory.current
cat /sys/fs/cgroup/system.slice/docker-<container-id>.scope/memory.max
```

### Ключевые контроллеры

**memory:**
```bash
# лимит памяти (в байтах)
echo 268435456 > /sys/fs/cgroup/mygroup/memory.max   # 256 MB

# что происходит при превышении:
# - OOM killer убивает процессы в группе
# - exit code 137 (SIGKILL)
# - в k8s: OOMKilled в describe pod
```

**cpu:**
```bash
# cpu.max: quota period (microseconds)
echo "50000 100000" > /sys/fs/cgroup/mygroup/cpu.max
# = 50% CPU (50ms из каждых 100ms)

# cpu.weight: относительный приоритет (1-10000, default 100)
echo 200 > /sys/fs/cgroup/mygroup/cpu.weight
```

**io (blkio в v1):**
```bash
# ограничение I/O (байт/сек на устройство)
echo "8:0 rbps=10485760" > /sys/fs/cgroup/mygroup/io.max   # 10 MB/s read
```

## Как Docker использует namespaces и cgroups

```
docker run --memory=256m --cpus=0.5 nginx
```

Под капотом (через containerd → runc):

1. `clone()` с флагами CLONE_NEWPID | CLONE_NEWNET | CLONE_NEWNS | CLONE_NEWUTS
2. Создание cgroup в `/sys/fs/cgroup/system.slice/docker-<id>.scope/`
3. Запись лимитов: `memory.max = 268435456`, `cpu.max = 50000 100000`
4. `chroot`/`pivot_root` в rootfs контейнера
5. `exec` процесса контейнера

## Связь с k8s resource limits

```yaml
# k8s manifest
resources:
  requests:
    memory: "128Mi"   # минимальная гарантия (влияет на scheduling)
    cpu: "250m"       # 0.25 CPU
  limits:
    memory: "256Mi"   # memory.max в cgroup
    cpu: "500m"       # cpu.max = 50000 100000 в cgroup
```

- **requests** — сколько ресурсов резервируется на ноде (влияет на scheduler)
- **limits.memory** → `memory.max` в cgroup → OOMKilled при превышении
- **limits.cpu** → `cpu.max` в cgroup → CPU throttling (не убивает, замедляет)

**QoS классы** (определяются автоматически):
- **Guaranteed**: requests == limits для всех контейнеров → последние выселяются при нехватке
- **Burstable**: limits > requests → средний приоритет
- **BestEffort**: нет ни requests, ни limits → первые выселяются
