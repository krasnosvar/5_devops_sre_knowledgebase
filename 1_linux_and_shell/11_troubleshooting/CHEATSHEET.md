# Траблшутинг Linux — шпаргалка

Подробности и объяснения — в
[linux_troubleshooting.md](./01_theory/linux_troubleshooting.md).
⚠️ — опасная команда или частая ловушка.

## Методики

| Методика | Для чего | Метрики |
| :--- | :--- | :--- |
| USE (Gregg) | ресурсы: CPU, RAM, диск, сеть | Utilization, Saturation, Errors |
| RED (Wilkie) | сервисы, L7 | Rate, Errors, Duration (p95/p99) |

## Первые 60 секунд

| # | Команда | Смотрим |
| :--- | :--- | :--- |
| 1 | `uptime` | load average 1/5/15 — растёт или падает |
| 2 | `dmesg -T --level=emerg,alert,crit,err \| tail -30` | OOM, I/O errors, drop, hung task (нужен root или `journalctl -k`) |
| 3 | `vmstat 1 5` | `r`, `b`, `si`/`so`, `wa`, `st`, `cs` |
| 4 | `mpstat -P ALL 1 1` | перекос на одно ядро, `%soft`, `%steal` |
| 5 | `pidstat 1 3` | кто ест CPU (`%usr` vs `%system`) |
| 6 | `iostat -xz 1 3` | `r_await`/`w_await`, `aqu-sz`, `%util` |
| 7 | `free -h` | `available`, swap |
| 8 | `sar -n DEV 1 3` | трафик, `%ifutil` |
| 9 | `sar -n TCP,ETCP 1 3` | `retrseg/s`, `estres/s`, `orsts/s` |
| 10 | `top -b -n 1 \| head -25` | общая картина |

## CPU

| Метрика | Норма / тревога |
| :--- | :--- |
| Load average | в Linux = R + **D**; высокий LA при низком CPU → ищи D-state |
| `vmstat r` | стабильно > числа vCPU (×2–3) — перегруз планировщика |
| `vmstat b` | > 0 долго — процессы в D (I/O) |
| `%st` (steal) | > 5–10 % — соседи по гипервизору отбирают CPU |
| `cs` | > 100k/с — contention (`futex`), мелкие пакеты, троттлинг |
| PSI | `cat /proc/pressure/cpu` — `some avg10` > 0 = задачи ждут CPU |

| Задача | Команда |
| :--- | :--- |
| Процессы в D-state и где ждут | `ps -eo state,pid,ppid,comm,wchan:25 \| awk '$1 ~ /D/'` |
| Стек ядра процесса | `sudo cat /proc/<PID>/stack` |
| Троттлинг контейнера | `cat /sys/fs/cgroup/<путь>/cpu.stat` (`nr_throttled`) |

## Память

| Метрика | Смысл |
| :--- | :--- |
| `free` мал | ⚠️ норма: память под page cache |
| `available` | реальный запас без ухода в swap |
| `si`/`so` в vmstat > 0 | активный swap — thrashing |
| `SUnreclaim` растёт | утечка в ядре (slab) |
| PSS | честная память процесса (`/proc/<PID>/smaps_rollup`) |

| Задача | Команда |
| :--- | :--- |
| Сводка | `grep -E 'MemAvailable\|^Cached\|Dirty\|Slab\|SReclaimable\|SUnreclaim' /proc/meminfo` |
| Топ slab-кэшей | `sudo slabtop -o -s c \| head -20` |
| Был ли OOM | `journalctl -k -g 'Out of memory\|oom-kill'` |
| Давление на память | `cat /proc/pressure/memory` |
| Топ по RSS | `ps -eo pid,rss,comm --sort=-rss \| head` |

## Диск

| Метрика `iostat -xz 1` | Норма / тревога |
| :--- | :--- |
| `r_await` / `w_await` | NVMe < 1 мс, SATA SSD < 5 мс, HDD 10–20 мс |
| `aqu-sz` | > 2–3 на канал — насыщение |
| `%util` 100 % | на HDD — насыщение; ⚠️ на NVMe/SSD ничего не значит, смотри `await` |

| Задача | Команда |
| :--- | :--- |
| Кто пишет / читает | `pidstat -d 1`, `sudo iotop -o` |
| `df` 100 %, `du` меньше | `sudo lsof +L1`, освободить: `: > /proc/<PID>/fd/<FD>` |
| Кончились inodes | `df -i`; `find / -xdev -printf '%h\n' \| sort \| uniq -c \| sort -n \| tail` |
| Давление на I/O | `cat /proc/pressure/io` |

## Сеть

| Где теряется пакет | Команда |
| :--- | :--- |
| NIC / ring buffer | `ip -s link show eth0`, `ethtool -S eth0 \| grep -iE 'drop\|miss'`, `ethtool -g eth0` |
| softirq backlog | `cat /proc/net/softnet_stat` (столбцы hex: 1 — обработано, 2 — dropped, 3 — time_squeeze) |
| Listen backlog | `ss -lnt` (Recv-Q ≥ Send-Q), `nstat -az TcpExtListenOverflows` |
| Ретрансмиты | `nstat -az TcpRetransSegs`, `sar -n ETCP 1` |
| conntrack | `cat /proc/sys/net/netfilter/nf_conntrack_{count,max}`; `dmesg`: `table full, dropping packet` |

| Задача | Команда |
| :--- | :--- |
| Увеличить ring buffer ⚠️ кратковременный сброс линка | `sudo ethtool -G eth0 rx 4096` |
| Топ источников в conntrack | `sudo conntrack -L \| awk '{for (i = 1; i <= NF; i++) if ($i ~ /^src=/) {print substr($i, 5); break}}' \| sort \| uniq -c \| sort -nr \| head` |
| Поднять лимит conntrack | `sudo sysctl -w net.netfilter.nf_conntrack_max=262144` |

## Трассировка

| Задача | Команда |
| :--- | :--- |
| Сводка syscalls ⚠️ замедляет в разы | `sudo strace -c -f -p <PID>` |
| Только ошибки сети/файлов | `sudo strace -f -e trace=network,file -Z -p <PID>` |
| CPU-профиль | `sudo perf record -F 99 -g -p <PID> -- sleep 10`, `perf report --stdio` |
| Короткоживущие процессы | `sudo execsnoop` (BCC) |
| Латентность блочного I/O | `sudo biolatency` (BCC) |
| Ретрансмиты с адресами | `sudo tcpretrans` (BCC) |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| LA высокий, CPU низкий | D-state: `vmstat b`, `ps … wchan`, NFS/диск |
| Exit code 137 без логов | OOM: `journalctl -k`, `memory.events` |
| p99 растёт, CPU не 100 % | steal, троттлинг cgroup, `runqlat` |
| `No space left` при свободном месте | `df -i` |
| Таймауты подключений | backlog, conntrack, SYN-ретрансмиты |
| `kill -9` не убивает | `D` — ждёт I/O; `Z` — уже мёртв, нужен `wait()` родителя |
| ФС стала read-only | `dmesg -T \| grep -iE 'I/O error\|remount'` |

⚠️ `tcp_tw_recycle` удалён в ядре 4.12 — ломал клиентов за NAT; используйте
keep-alive и `tcp_tw_reuse=1`.

> Проверка: `vmstat`, `mpstat`, `iostat -xz`, `sar -n DEV/TCP,ETCP`,
> `pidstat`, `free`, `/proc/pressure/*`, `softnet_stat`, `nstat`,
> `slabtop --help`, `uptime` — запущены локально (sysstat 12.x,
> procps-ng 4.x, kernel 7.2), названия колонок сверены; не проверено:
> `dmesg` (нужен root), `ethtool -G`, `conntrack -L` (утилита не
> установлена; awk-разбор `src=` проверен на образце вывода TCP/UDP),
> `iotop`, `perf`, BCC.
