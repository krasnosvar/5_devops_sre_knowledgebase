# Cgroups и namespaces — шпаргалка

Подробности и объяснения — в
[cgroups_namespaces.md](./01_theory/cgroups_namespaces.md).
⚠️ — опасная команда или частая ловушка.

## Какая версия cgroups

| Задача | Команда |
| :--- | :--- |
| v2 или v1 | `stat -fc %T /sys/fs/cgroup/` → `cgroup2fs` = v2, `tmpfs` = v1/hybrid |
| В какой cgroup процесс | `cat /proc/<PID>/cgroup` (v2: одна строка `0::/путь`) |
| Доступные контроллеры | `cat /sys/fs/cgroup/cgroup.controllers` |
| Дерево cgroups с процессами | `systemd-cgls` |
| Топ cgroups по CPU / памяти | `systemd-cgtop -c` / `systemd-cgtop -m` |

## Файлы cgroups v2

| Файл | Смысл | Пример / дефолт |
| :--- | :--- | :--- |
| `cpu.weight` | доля CPU при конкуренции (k8s requests) | `1..10000`, дефолт `100` |
| `cpu.max` | жёсткий лимит CFS: `<quota> <period>` (k8s limits) | `50000 100000` = 0.5 CPU; `max 100000` = без лимита |
| `cpu.stat` | `nr_throttled`, `throttled_usec` — троттлинг | растёт → упираемся в `cpu.max` |
| `memory.max` | жёсткий лимит, дальше OOM в группе | `max` = без лимита |
| `memory.high` | мягкий порог: reclaim и замедление, без kill | |
| `memory.current` | текущее потребление | |
| `memory.events` | `high`, `max`, `oom`, `oom_kill` | `oom_kill` > 0 → был OOMKilled |
| `memory.stat` | `anon`, `file`, `kernel` и т. д. | |
| `pids.max` / `pids.current` | лимит процессов+потоков (fork-бомба) | |
| `io.max` | лимит IOPS/байт на устройство | `8:0 rbps=10485760 wiops=100` |
| `cpu.pressure`, `memory.pressure`, `io.pressure` | PSI: доля времени в ожидании ресурса | `some avg10=…` |
| `cgroup.procs` | PID-ы группы; запись PID переносит процесс | |
| `cgroup.subtree_control` | какие контроллеры включены детям | `+cpu +memory` |

| v1 (legacy) | v2 |
| :--- | :--- |
| `cpu.shares` (дефолт 1024) | `cpu.weight` (дефолт 100) |
| `cpu.cfs_quota_us` + `cpu.cfs_period_us` | `cpu.max` |
| `memory.limit_in_bytes` | `memory.max` |
| `blkio.*` | `io.*` |
| отдельное дерево на контроллер | одно дерево, процесс ровно в одной группе |

⚠️ Видите `cpu.shares`/`memory.limit_in_bytes` в скрипте — это v1, на хосте
с v2 таких файлов нет.

## Типовые проверки

| Задача | Команда |
| :--- | :--- |
| Лимит и потребление памяти контейнера | `d=/sys/fs/cgroup/$(cut -d: -f3 /proc/<PID>/cgroup)`<br>`cat $d/memory.max $d/memory.current $d/memory.events` |
| Троттлится ли CPU | `cat $d/cpu.max $d/cpu.stat` |
| Запустить команду с лимитами (systemd) | `systemd-run --scope -p MemoryMax=512M -p CPUQuota=50% <cmd>` (без root: `--user`) |
| Лимит на работающий сервис ⚠️ меняет прод | `sudo systemctl set-property nginx.service MemoryMax=1G` |
| Лимиты сервиса | `systemctl show nginx -p MemoryMax,CPUQuotaPerSecUSec,TasksMax` |

## Namespaces

| Namespace | Изолирует | Флаг `clone()` | `nsenter` |
| :--- | :--- | :--- | :--- |
| PID | дерево процессов | `CLONE_NEWPID` | `-p` |
| NET | интерфейсы, маршруты, netfilter, сокеты | `CLONE_NEWNET` | `-n` |
| MNT | точки монтирования | `CLONE_NEWNS` | `-m` |
| UTS | hostname, domainname | `CLONE_NEWUTS` | `-u` |
| IPC | SysV IPC, POSIX MQ | `CLONE_NEWIPC` | `-i` |
| USER | маппинг UID/GID | `CLONE_NEWUSER` | `-U` |
| CGROUP | видимое дерево cgroups | `CLONE_NEWCGROUP` | `-C` |
| TIME | смещение monotonic/boottime | `CLONE_NEWTIME` | `-T` |

| Задача | Команда |
| :--- | :--- |
| Все namespaces в системе | `lsns` (только сетевые: `lsns -t net`) |
| Namespaces процесса | `ls -l /proc/<PID>/ns/` |
| PID контейнера на хосте | `docker inspect -f '{{.State.Pid}}' <ctr>` / `crictl inspect <id>` |
| Войти в сеть контейнера с утилитами хоста | `sudo nsenter -t <PID> -n ip addr`<br>`sudo nsenter -t <PID> -n tcpdump -i eth0 -nn` |
| Войти во все namespaces | `sudo nsenter -t <PID> -a sh` |
| Изолированный PID ns без root | `unshare -r -p -f --mount-proc ps` (увидите только `PID 1`) |
| Свой hostname в новом UTS ns | `unshare -r -u sh -c 'hostname test; hostname'` |
| Маппинг UID в user ns | `cat /proc/<PID>/uid_map` (`0 100000 65536`) |

⚠️ Root внутри user namespace мапится на непривилегированный UID хоста
(например, `100000`); `nobody` (65534) показывается только для
немапленных UID.

⚠️ `top`/`free` в контейнере читают `/proc/meminfo` хоста и показывают его
RAM, а не `memory.max` — приложение может выделить кэш «под хост» и
получить OOM.

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| `OOMKilled`, exit 137 | `memory.events` (`oom_kill`), `journalctl -k \| grep -i oom` |
| Высокая latency при низком CPU | `cpu.stat` → `nr_throttled`, `throttled_usec` |
| `fork: Resource temporarily unavailable` | `pids.current` vs `pids.max` |
| Медленно, но не убивает | `memory.high`, `memory.pressure` |

> Проверка: `stat -fc`, `/proc/self/cgroup`, `lsns`, `nsenter --help`,
> `unshare -r -p -f --mount-proc`, `systemd-run --user --scope -p MemoryMax
> -p CPUQuota` (проверены значения `memory.max`/`cpu.max`), `systemd-cgtop
> --help` — локально (systemd 259, util-linux 2.41, cgroups v2);
> не проверено: `systemctl set-property` и `nsenter` в чужой процесс
> (нужен root), `crictl`.
