# Файловая система и монтирование

## VFS — Virtual File System

VFS — абстрактный слой в ядре. Единый интерфейс `open/read/write` для
ext4, xfs, btrfs, tmpfs, overlay, proc, sysfs и других.

```bash
# посмотреть типы ФС смонтированных систем
findmnt --output TARGET,SOURCE,FSTYPE,OPTIONS
cat /proc/mounts

# типы ФС на дисках
lsblk -f
blkid /dev/sda1
```

## Mount namespaces и bind mounts

**Mount namespace** — каждый контейнер имеет свой набор mountpoints.
Изменения внутри контейнера не видны хосту.

**Bind mount** — монтирование директории хоста внутрь контейнера:

```bash
# bind mount (ядерный вызов)
mount --bind /host/data /container/data
# или в Docker:
docker run -v /host/data:/container/data nginx

# read-only bind mount
mount --bind -o ro /host/config /container/config
docker run -v /host/config:/container/config:ro nginx

# посмотреть все bind mounts
findmnt --list | grep bind
```

## overlayfs — слоёная ФС контейнеров

```bash
# overlayfs вручную (как Docker делает для контейнеров)
mkdir -p /tmp/overlay/{lower1,lower2,upper,work,merged}
echo "base" > /tmp/overlay/lower1/file.txt
echo "layer2" > /tmp/overlay/lower2/new.txt

mount -t overlay overlay \
  -o lowerdir=/tmp/overlay/lower2:/tmp/overlay/lower1,\
     upperdir=/tmp/overlay/upper,\
     workdir=/tmp/overlay/work \
  /tmp/overlay/merged

ls /tmp/overlay/merged   # видим оба файла
echo "modified" > /tmp/overlay/merged/file.txt
cat /tmp/overlay/upper/file.txt  # копия в upperdir (COW)
cat /tmp/overlay/lower1/file.txt # нижний слой неизменён
```

## tmpfs — RAM-диск

tmpfs хранит данные в памяти. Быстрый, но данные пропадают при перезагрузке.
В контейнерах используется для `--tmpfs` (временные файлы при read-only rootfs).

```bash
mount -t tmpfs tmpfs /tmp/ramdisk -o size=256m
df -h /tmp/ramdisk   # виден как обычный диск

# в k8s: emptyDir с medium: Memory
volumes:
  - name: cache
    emptyDir:
      medium: Memory
      sizeLimit: 256Mi
```

## /proc и /sys — интерфейсы ядра

```bash
# /proc — информация о процессах и ядре
/proc/PID/         # информация о конкретном процессе
/proc/meminfo      # статистика памяти
/proc/cpuinfo      # информация о CPU
/proc/net/tcp      # TCP соединения (числа в hex)
/proc/sys/         # изменяемые параметры (sysctl)

# чтение и изменение параметров ядра
sysctl net.ipv4.ip_forward
sysctl -w net.ipv4.ip_forward=1        # временно
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf  # постоянно
sysctl -p                               # применить из файла

# /sys — устройства и драйверы
/sys/block/sda/queue/scheduler     # планировщик I/O
/sys/class/net/eth0/speed          # скорость интерфейса
/sys/devices/                       # иерархия устройств
```

## inode — метаданные файла

inode хранит: тип файла, права, UID/GID, размер, timestamps, указатели на блоки данных.
Имя файла хранится в директории (не в inode).

```bash
# inode номер файла
ls -i /etc/hosts
stat /etc/hosts     # полная информация включая inode

# жёсткие ссылки — несколько имён на один inode
ln /etc/hosts /tmp/hosts-copy
ls -i /etc/hosts /tmp/hosts-copy  # одинаковый inode

# исчерпание inodes (нет места хотя диск не полный)
df -i              # использование inodes
find /tmp -maxdepth 2 | wc -l   # найти директорию с множеством мелких файлов
```

## Важные mountpoints в Linux

```
/        — корень (обычно ext4/xfs)
/boot    — ядро и bootloader (отдельный раздел)
/tmp     — временные файлы (иногда tmpfs)
/var     — переменные данные: логи, БД, кеш
/run     — runtime данные (tmpfs, чистится при загрузке)
/dev     — устройства (devtmpfs)
/proc    — процессы и ядро (procfs, виртуальная)
/sys     — устройства и параметры (sysfs, виртуальная)
/dev/shm — shared memory (tmpfs)
```
