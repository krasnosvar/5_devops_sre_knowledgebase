# Файловая система и монтирование — шпаргалка

Подробности и объяснения — в
[filesystem_mounts.md](./01_theory/filesystem_mounts.md).
⚠️ — опасная команда или частая ловушка.

## Место и inodes

| Задача | Команда |
| :--- | :--- |
| Место по ФС с типом | `df -hT` |
| Inodes | `df -i` |
| Что занимает место (одна ФС) | `du -xh --max-depth=1 / \| sort -h \| tail` |
| Каталоги с наибольшим числом файлов | `find / -xdev -printf '%h\n' 2>/dev/null \| sort \| uniq -c \| sort -n \| tail` |
| Удалённые, но открытые файлы | `lsof +L1` |
| Освободить место открытого лога ⚠️ данные теряются | `: > /proc/<PID>/fd/<FD>` или `truncate -s0 <file>` |
| Inode файла и число hardlinks | `stat <file>`, `ls -li` |
| Найти все hardlinks на inode | `find / -xdev -inum <N>` |

## Диски и монтирование

| Задача | Команда |
| :--- | :--- |
| Блочные устройства, ФС, UUID | `lsblk -f`, `blkid` |
| Дерево монтирования с опциями | `findmnt` (`findmnt -T /var/lib` — на какой ФС путь) |
| Только реальные ФС | `findmnt -t ext4,xfs,btrfs` |
| Проверить `/etc/fstab` до reboot | `sudo findmnt --verify` |
| Применить fstab без reboot | `sudo mount -a` (после правки: `systemctl daemon-reload`) |
| Перемонтировать с новыми опциями | `sudo mount -o remount,ro /data` |
| Bind mount | `sudo mount --bind /src /dst` (с вложенными: `--rbind`) |
| tmpfs | `sudo mount -t tmpfs -o size=512M tmpfs /mnt/tmp` |
| Кто мешает размонтировать | `fuser -vm /mnt/data`, `lsof +f -- /mnt/data` |
| Отцепить зависший NFS ⚠️ | `umount -f /mnt/nfs` (принудительно) / `umount -l` (lazy) |

```text
# /etc/fstab: <источник> <точка> <тип> <опции> <dump> <fsck>
UUID=…  /data  xfs  defaults,noatime,nofail  0 0
```

⚠️ Используйте `UUID=`, а не `/dev/sdb1` — имена устройств меняются между
загрузками. `nofail` — чтобы нода загрузилась без этого диска.

## Page cache и writeback

| Задача | Команда |
| :--- | :--- |
| Dirty / Writeback сейчас | `grep -E '^(Dirty\|Writeback):' /proc/meminfo` |
| Сбросить dirty на диск | `sync` |
| Сбросить page cache ⚠️ просадка I/O после | `sync; echo 3 \| sudo tee /proc/sys/vm/drop_caches` |

| sysctl | Дефолт | Смысл |
| :--- | :--- | :--- |
| `vm.dirty_background_ratio` | `10` | % RAM dirty → фоновый сброс |
| `vm.dirty_ratio` | `20` | % RAM dirty → писатель блокируется |
| `vm.dirty_expire_centisecs` | `3000` | dirty старше 30 с сбрасывается |
| `vm.dirty_writeback_centisecs` | `500` | flusher просыпается раз в 5 с |

## Swap

| Задача | Команда |
| :--- | :--- |
| Активный swap | `swapon --show`, `free -h` |
| Кто в swap | `grep VmSwap /proc/*/status \| sort -k2 -n \| tail` |
| Swappiness | `sysctl vm.swappiness` (дефолт `60`, диапазон `0..200` с ядра 5.8) |
| Создать swap-файл (ext4/xfs) | `fallocate -l 4G /swapfile && chmod 600 /swapfile`<br>`mkswap /swapfile && swapon /swapfile` |

## ext4 vs XFS

| | ext4 | XFS |
| :--- | :--- | :--- |
| Дефолт в | Debian/Ubuntu | RHEL-семейство |
| Inodes | фиксируются при `mkfs` (`-i`, `-N`) | выделяются динамически |
| Увеличить онлайн | `resize2fs /dev/vg/lv` | `xfs_growfs /mount/point` |
| Уменьшить | только офлайн | ⚠️ нельзя |
| Инфо о ФС | `tune2fs -l /dev/…` | `xfs_info /mount/point` |
| Проверка ⚠️ только размонтированной | `fsck.ext4 -f /dev/…` | `xfs_repair /dev/…` |

## LVM

| Задача | Команда |
| :--- | :--- |
| Обзор | `pvs`, `vgs`, `lvs` |
| Новый диск в пул | `pvcreate /dev/sdc`<br>`vgextend vg0 /dev/sdc` |
| Расширить LV и ФС одной командой | `lvextend -r -L +20G /dev/vg0/data` (`-l +100%FREE` — всё свободное) |
| Снапшот | `lvcreate -s -L 5G -n data_snap /dev/vg0/data` |

Слои: PV (диск/раздел) → VG (пул) → LV (том) → ФС.

## Контейнерные ФС

| Тип | Суть | Где встречается |
| :--- | :--- | :--- |
| bind mount | каталог хоста поверх каталога в контейнере | `docker -v /host:/ctr`, `hostPath` |
| tmpfs | ФС в RAM, исчезает при остановке | `emptyDir.medium: Memory` |
| OverlayFS | lowerdir (образ, RO) + upperdir (контейнер) + copy-up при записи | слои образов |

| Задача | Команда |
| :--- | :--- |
| Overlay-маунты на хосте | `findmnt -t overlay` |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| `No space left on device`, а `df -h` есть место | `df -i` — кончились inodes |
| `df` 100 %, `du` меньше | `lsof +L1` |
| `umount: target is busy` | `fuser -vm`, `lsof +f --` |
| Процессы в `D`, висит `df` | мёртвый NFS: `findmnt -t nfs,nfs4`, `umount -l` |
| ФС стала read-only | `dmesg -T \| grep -iE 'ext4\|xfs\|I/O error'` |

> Проверка: `df`, `du`, `lsblk -f`, `findmnt` (`-T`, `-t`, `--verify`),
> `mount --help` (`--bind`/`--rbind`), `swapon --show`, sysctl-дефолты
> `vm.dirty_*`/`swappiness` — локально (util-linux 2.41, kernel 7.2);
> не проверено: команды LVM, `mkswap`/`swapon`, `xfs_growfs`/`resize2fs`,
> `fsck`/`xfs_repair`, `drop_caches` (нужен root и меняют систему).
