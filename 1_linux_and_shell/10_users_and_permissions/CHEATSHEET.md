# Пользователи, группы и ACL — шпаргалка

Подробности и объяснения — в
[users_and_permissions.md](./01_theory/users_and_permissions.md).
SUID, sudo, PAM, SELinux — в [09_linux_security](../09_linux_security/).
⚠️ — опасная команда или частая ловушка.

## Кто есть кто

| Задача | Команда |
| :--- | :--- |
| UID, GID, все группы | `id alice` |
| Пользователь из любого источника NSS | `getent passwd alice` ⚠️ `grep /etc/passwd` не видит LDAP/SSSD |
| Группа и её участники | `getent group docker` |
| Группы текущей сессии | `id -Gn` (или `groups`) |
| Порядок источников | `grep -E '^(passwd\|group):' /etc/nsswitch.conf` |
| Системные аккаунты | `awk -F: '$3 < 1000' /etc/passwd` |
| Кто залогинен / история входов | `who`, `w` / `last -n 20`, `lastb` (неудачные, root) |

## Файлы учётных записей

| Файл | Формат | Права |
| :--- | :--- | :--- |
| `/etc/passwd` | `name:x:UID:GID:GECOS:home:shell` | `644`, читают все |
| `/etc/shadow` | `name:hash:lastchg:min:max:warn:inactive:expire:` | Debian `640 root:shadow`, RHEL `000 root:root` |
| `/etc/group` | `name:x:GID:user1,user2` | `644` |
| `/etc/login.defs` | `UID_MIN`/`UID_MAX`, `SYS_UID_*`, `UMASK` | |
| `/etc/skel/` | шаблон домашнего каталога для `useradd -m` | |

| Префикс хэша | Алгоритм |
| :--- | :--- |
| `$6$` | SHA-512 |
| `$y$` | yescrypt (дефолт в свежих Debian/Fedora) |
| `!` / `*` в начале | пароль заблокирован / не задан |

| UID | Кто |
| :--- | :--- |
| `0` | root |
| `1..999` | системные (демоны), `useradd -r` |
| `1000+` | люди (`UID_MIN`) |
| `65534` | `nobody` |

## Управление аккаунтами

| Задача | Команда |
| :--- | :--- |
| Создать человека | `sudo useradd -m -s /bin/bash -c "Alice Smith" alice` |
| Сервисный аккаунт | `sudo useradd -r -s /usr/sbin/nologin svc_backup` |
| Задать пароль | `sudo passwd alice` |
| Добавить в группу | `sudo usermod -aG docker alice` ⚠️ без `-a` заменит **все** группы |
| То же, без ловушки | `sudo gpasswd -a alice docker` (убрать: `-d`) |
| Сменить shell / home | `sudo usermod -s /bin/zsh alice` / `usermod -d /new -m alice` |
| Заблокировать / разблокировать | `sudo usermod -L alice` / `-U` (или `passwd -l` / `-u`) |
| Срок действия аккаунта | `sudo chage -E 2026-12-31 alice` |
| Политика пароля | `sudo chage -l alice`, `sudo chage -M 90 alice` |
| Удалить с домашним каталогом ⚠️ | `sudo userdel -r alice` |
| Новая группа | `sudo groupadd -r appgroup` |
| Подхватить группу без релогина | `newgrp docker` (только в этом shell) |

⚠️ Новая группа применяется к **новым** сессиям — уже открытый shell её
не видит.

| Shell | Поведение |
| :--- | :--- |
| `/usr/sbin/nologin` | вход запрещён с сообщением |
| `/bin/false` | вход запрещён молча |

## Классические права

| Задача | Команда |
| :--- | :--- |
| Права числом и владелец | `stat -c '%A %a %U:%G %n' file` |
| Сменить владельца рекурсивно | `sudo chown -R app:app /srv/app` |
| Права числом | `chmod 640 file`, `chmod 750 dir` |
| Только каталогам / только файлам | `find /srv/app -type d -exec chmod 750 {} +`<br>`find /srv/app -type f -exec chmod 640 {} +` |
| `X` — exec только каталогам | `chmod -R u=rwX,g=rX,o= /srv/app` |
| Текущая маска | `umask` (`022` → файлы `644`, каталоги `755`) |

| Право | На файле | На каталоге |
| :--- | :--- | :--- |
| `r` (4) | читать | список имён |
| `w` (2) | изменять | создавать / удалять / переименовывать файлы |
| `x` (1) | запускать | входить (`cd`), доступ к файлам по имени |

⚠️ Удаление файла зависит от прав на **каталог**, а не на файл.

## POSIX ACL

| Задача | Команда |
| :--- | :--- |
| Дать доступ пользователю | `setfacl -m u:alice:rx /opt/app/config.yaml` |
| Дать доступ группе | `setfacl -m g:devs:rwx /srv/shared` |
| Наследование новым файлам | `setfacl -d -m u:alice:rx /srv/shared` |
| Применить к существующим | `setfacl -R -m u:alice:rX /srv/shared` |
| Посмотреть | `getfacl file` (`#effective:` — урезано mask) |
| Ограничить mask | `setfacl -m mask::r-- file` |
| Убрать одну запись / все ACL | `setfacl -x u:alice file` / `setfacl -b file` |
| Бэкап / восстановление ACL | `getfacl -R /srv > acl.txt` / `setfacl --restore=acl.txt` |
| Копировать с ACL | `cp -a`, `rsync -aAX`, `tar --acls` |

| Признак | Смысл |
| :--- | :--- |
| `+` в `ls -l` (`-rw-r-xr--+`) | у файла есть ACL |
| `mask::` | верхняя граница для именованных записей и группы |
| `chmod g…` на файле с ACL | ⚠️ меняет `mask`, а не права группы-владельца |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| Пропал доступ к docker/sudo после `usermod` | забыли `-a`: `id user`, вернуть группы |
| `permission denied` на docker.sock сразу после добавления в группу | старая сессия: релогин или `newgrp docker` |
| ACL выдан, а доступа нет | `getfacl` → `#effective:` и `mask` |
| Не может войти в каталог | нет `x` на каком-то каталоге пути: `namei -l /path/to/file` |
| Пользователь логинится, но нет в `/etc/passwd` | LDAP/SSSD: `getent passwd`, `nsswitch.conf` |

> Проверка: `setfacl`/`getfacl` (`-m`, `-d`, mask, `#effective`, сдвиг
> mask от `chmod g+w`, `-b`, `-R`) проверены на файлах в scratch; `id`,
> `getent`, `stat -c`, `umask`, `login.defs`, флаги `useradd`/`usermod`/
> `chage`/`passwd`/`gpasswd` сверены с `--help` (shadow-utils 4.x,
> Fedora 44); не проверено: команды, создающие/меняющие аккаунты (нужен
> root), `lastb`.
