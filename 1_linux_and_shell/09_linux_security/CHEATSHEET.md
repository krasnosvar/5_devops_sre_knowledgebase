# Безопасность Linux — шпаргалка

Подробности и объяснения — в [linux_security.md](./01_theory/linux_security.md).
Аккаунты и ACL — в [10_users_and_permissions](../10_users_and_permissions/).
⚠️ — опасная команда или частая ловушка.

## Специальные биты и capabilities

| Задача | Команда |
| :--- | :--- |
| SUID / SGID / sticky | `chmod u+s` (`4xxx`) / `chmod g+s` (`2xxx`) / `chmod +t` (`1xxx`) |
| Аудит SUID/SGID-бинарников | `find / -xdev -perm /6000 -type f 2>/dev/null` (только SUID: `-perm -4000`) |
| Файлы с capabilities | `getcap -r / 2>/dev/null` |
| Дать capability вместо SUID | `sudo setcap cap_net_bind_service=+ep /usr/local/bin/app` |
| Capabilities процесса | `grep Cap /proc/<PID>/status`, расшифровать: `capsh --decode=<hex>` |
| ruid / euid процесса | `ps -o pid,ruser,euser,comm -p <PID>` |

| Бит | В `ls -l` | Эффект |
| :--- | :--- | :--- |
| SUID | `-rwsr-xr-x` | процесс получает euid владельца (`passwd`) |
| SGID на каталоге | `drwxrwsr-x` | новые файлы наследуют группу каталога |
| sticky | `drwxrwxrwt` | удалять файл может только владелец (`/tmp`) |

## sudo и PAM

| Задача | Команда |
| :--- | :--- |
| Править sudoers безопасно | `sudo visudo` / drop-in: `sudo visudo -f /etc/sudoers.d/deploy` |
| Проверить синтаксис | `sudo visudo -c` |
| Что мне разрешено | `sudo -l` |
| Разблокировать после faillock | `sudo faillock --user alice --reset` (смотреть: `faillock --user alice`) |
| PAM-стек сервиса | `cat /etc/pam.d/sshd` |

```text
# /etc/sudoers.d/deploy — точечно, с полным путём
deploy ALL=(root) NOPASSWD: /usr/bin/systemctl restart myapp.service
```

⚠️ `NOPASSWD: ALL` = root без барьера. Без полного пути к бинарнику можно
подсунуть свой через `PATH`.

## SSH hardening

```text
# /etc/ssh/sshd_config.d/00-hardening.conf  (первое значение побеждает!)
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AllowUsers deploy alice
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
```

| Задача | Команда |
| :--- | :--- |
| Проверить конфиг | `sudo sshd -t` |
| Реально применяемые значения | `sudo sshd -T \| grep -iE 'passwordauth\|permitroot'` |
| Перечитать без разрыва сессий | `sudo systemctl reload sshd` (Debian/Ubuntu: `ssh`) |
| Неудачные входы | `journalctl -u sshd -g 'Failed\|Invalid'` |

⚠️ Перед reload держите вторую открытую SSH-сессию — ошибка в конфиге
отрежет доступ. ⚠️ В `sshd_config.d/` облачный `50-cloud-init.conf`
побеждает `99-*.conf` (sshd берёт **первое** значение); в `sysctl.d/` —
наоборот, побеждает последний файл.

## SELinux

| Задача | Команда |
| :--- | :--- |
| Режим | `getenforce`, `sestatus` |
| Временно Permissive ⚠️ до reboot | `sudo setenforce 0` (постоянно: `SELINUX=` в `/etc/selinux/config`) |
| Контексты файлов / процессов | `ls -Z /var/www/html`, `ps -eZ \| grep nginx` |
| Что заблокировано | `sudo ausearch -m avc -ts recent` |
| Почему и как разрешить | `sudo ausearch -m avc -ts recent \| audit2why` |
| Вернуть контексты по политике | `sudo restorecon -Rv /var/www/html` |
| Постоянный контекст для пути | `sudo semanage fcontext -a -t httpd_sys_content_t '/srv/web(/.*)?'` + `restorecon` |
| Нестандартный порт сервису | `sudo semanage port -a -t http_port_t -p tcp 8081` |
| Переключатели политики | `getsebool -a \| grep httpd`, `sudo setsebool -P httpd_can_network_connect on` |

⚠️ `chcon` не переживёт relabel — для постоянства `semanage fcontext`.
⚠️ Disabled → Enforcing: сначала Permissive + `touch /.autorelabel`, иначе
`unlabeled_t` сломает сервисы.

## AppArmor

| Задача | Команда |
| :--- | :--- |
| Загруженные профили и режимы | `sudo aa-status` |
| Черновик профиля по логам | `sudo aa-genprof /usr/sbin/myapp` |
| Режим логирования / блокировки | `sudo aa-complain <профиль>` / `sudo aa-enforce <профиль>` |
| Нарушения | `journalctl -k -g apparmor` |

⚠️ `complain` ничего не блокирует — «профиль загружен» ≠ «защищает».

## auditd

| Задача | Команда |
| :--- | :--- |
| Следить за файлом | `sudo auditctl -w /etc/sudoers -p wa -k sudoers` |
| Следить за syscalls | `sudo auditctl -a always,exit -F arch=b64 -S chmod,fchmod,chown -k perm` |
| Текущие правила | `sudo auditctl -l` |
| Постоянно | `/etc/audit/rules.d/*.rules` + `sudo augenrules --load` |
| Найти события по ключу | `sudo ausearch -k sudoers -i` |
| Отчёт по файлам | `sudo aureport -f -i` |

## sysctl hardening

| Параметр | Значение | Зачем |
| :--- | :--- | :--- |
| `kernel.randomize_va_space` | `2` | полный ASLR |
| `kernel.yama.ptrace_scope` | `1` | ptrace только своих потомков |
| `kernel.kptr_restrict` | `1`–`2` | скрыть адреса ядра |
| `kernel.dmesg_restrict` | `1` | `dmesg` только root |
| `net.ipv4.conf.all.rp_filter` | `1` | анти-spoofing |
| `net.ipv4.conf.all.accept_redirects` | `0` | без ICMP redirect |
| `net.ipv4.icmp_echo_ignore_broadcasts` | `1` | Smurf |

| Задача | Команда |
| :--- | :--- |
| Применить все `sysctl.d/` | `sudo sysctl --system` (файл: `/etc/sysctl.d/99-hardening.conf`) |
| Прочитать значение | `sysctl kernel.yama.ptrace_scope` |

## systemd sandboxing

```ini
[Service]
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=/var/lib/myapp
ProtectHome=true
PrivateTmp=true
ProtectKernelModules=true
RestrictAddressFamilies=AF_INET AF_INET6
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
```

| Задача | Команда |
| :--- | :--- |
| Оценка exposure сервиса | `systemd-analyze security nginx` |

> Проверка: hardening-конфиг прошёл `sshd -t`/`sshd -T` с тестовым host
> key (OpenSSH 10.2); sandbox-юнит — `systemd-analyze verify` и
> `security --offline=true` (systemd 259); `getcap`, `capsh --decode`,
> `sestatus`, `ls -Z`, `ps -eZ`, `auditctl -h`, `ausearch --help`,
> `sudo --help` — локально (Fedora 44, SELinux enforcing); не проверено:
> всё, что требует root (`setenforce`, `semanage`, `auditctl -w`,
> `faillock --reset`, `augenrules`), AppArmor (`aa-*` нет на Fedora).
