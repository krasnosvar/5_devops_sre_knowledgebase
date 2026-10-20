# Ядро, загрузка, SSH и время — шпаргалка

Подробности и объяснения — в
[boot_process_and_core_services.md](./01_theory/boot_process_and_core_services.md).
⚠️ — опасная команда или частая ловушка.

## Загрузка: этапы и куда смотреть

| Этап | Что происходит | Проверить / отладить |
| :--- | :--- | :--- |
| BIOS / UEFI | POST, поиск загрузчика | `[ -d /sys/firmware/efi ] && echo UEFI \|\| echo BIOS`<br>`efibootmgr -v` |
| GRUB2 | грузит `vmlinuz-*` и `initramfs` | `cat /proc/cmdline` — с какими параметрами стартовало ядро |
| Ядро | инициализация железа | `dmesg -T \| less`, `journalctl -k -b` |
| initramfs | драйверы, LVM/RAID/LUKS, монтирует rootfs | `lsinitrd` (RHEL) / `lsinitramfs` (Debian) |
| PID 1 (systemd) | `switch_root`, сервисы, fstab | `systemd-analyze`, `systemctl --failed` |

| Задача | Команда |
| :--- | :--- |
| Сколько заняла загрузка | `systemd-analyze` |
| Самые медленные юниты | `systemd-analyze blame` |
| Критический путь до target | `systemd-analyze critical-chain multi-user.target` |
| Логи прошлой загрузки | `journalctl -b -1 -p err` (список: `journalctl --list-boots`) |
| Какая версия ядра | `uname -r` |
| Пересобрать initramfs | `dracut -f` (RHEL) / `update-initramfs -u` (Debian) |
| Кто PID 1 | `ps -p 1 -o comm=` |

## Syscalls и кольца защиты

| Задача | Команда |
| :--- | :--- |
| Сводка syscalls процесса (время, ошибки) | `strace -c -p <PID>` ⚠️ замедляет процесс |
| Какие syscalls делает команда | `strace -f -e trace=openat,read,write <cmd>` |
| Доля времени в ядре vs user | `top` → `%sy` / `%us`; `pidstat -u 1` |

## SSH

| Задача | Команда |
| :--- | :--- |
| Создать ключ | `ssh-keygen -t ed25519 -C "you@host"` |
| Скопировать pubkey на сервер | `ssh-copy-id -i ~/.ssh/id_ed25519.pub user@host` |
| Запустить агент и добавить ключ | `eval "$(ssh-agent -s)"`<br>`ssh-add ~/.ssh/id_ed25519` |
| Ключи в агенте | `ssh-add -l` |
| Через бастион (без agent forwarding) | `ssh -J user@bastion user@target` |
| Agent forwarding ⚠️ root на бастионе может использовать ваш агент | `ssh -A user@bastion` |
| Отладка подключения | `ssh -vvv user@host` |
| Итоговый клиентский конфиг для хоста | `ssh -G host` |
| Итоговый конфиг sshd (что реально применится) | `sudo sshd -T` |
| Проверить sshd_config перед рестартом | `sudo sshd -t` |
| Отпечаток ключа хоста | `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub` |
| Удалить старый host key из known_hosts | `ssh-keygen -R host` |
| Локальный проброс порта | `ssh -L 5432:db.internal:5432 user@bastion` |

```text
# ~/.ssh/config
Host prod-*
    User deploy
    ProxyJump bastion
    IdentityFile ~/.ssh/id_ed25519
```

⚠️ Аутентификация по ключу — это подпись: клиент подписывает данные сессии
приватным ключом, сервер проверяет подпись публичным из `authorized_keys`.

⚠️ `~/.ssh` должен быть `700`, `authorized_keys` — `600`, иначе sshd
(`StrictModes yes`) молча игнорирует ключ.

## Время: chrony / NTP

| Задача | Команда |
| :--- | :--- |
| Синхронизировано ли время | `timedatectl` (`System clock synchronized: yes`) |
| Смещение и stratum текущего источника | `chronyc tracking` |
| Источники и их состояние | `chronyc sources -v` |
| Статистика по источникам | `chronyc sourcestats` |
| Принудительно «шагнуть» часы ⚠️ скачок времени | `sudo chronyc makestep` |
| Сменить часовой пояс | `sudo timedatectl set-timezone Europe/Moscow` |
| Статус systemd-timesyncd (если вместо chrony) | `timedatectl timesync-status` |

| Значение | Смысл |
| :--- | :--- |
| UDP 123 | порт NTP |
| Stratum 0 / 1 / 2 | эталон (GPS, атомные) / подключён к эталону / берёт у stratum 1 |
| Stratum 16 | не синхронизирован |
| `makestep 1.0 3` (chrony.conf) | шаг, если смещение > 1 с, только в первые 3 обновления; дальше — slew |
| `^*` в `chronyc sources` | текущий выбранный источник |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| Не грузится после обновления ядра | GRUB → предыдущее ядро; `journalctl -b -1 -k` |
| Падает в `dracut`/`initramfs` shell | нет драйвера/UUID rootfs: `blkid`, `/etc/fstab`, пересобрать initramfs |
| Долгая загрузка | `systemd-analyze blame`, `critical-chain` |
| `Permission denied (publickey)` | `ssh -vvv`, права `~/.ssh`, `journalctl -u sshd` на сервере |
| TLS/JWT «not yet valid» | `timedatectl`, `chronyc tracking` |

> Проверка: флаги `journalctl`, `systemd-analyze`, `chronyc`, `timedatectl`,
> `ssh`/`ssh -G` сверены с `--help` (systemd 259, chrony 4.x, OpenSSH 10.x,
> Fedora 44); не проверено: `efibootmgr`, `lsinitrd`/`lsinitramfs`,
> `update-initramfs`, `dracut -f` (не запускались — меняют систему или
> отсутствуют).
