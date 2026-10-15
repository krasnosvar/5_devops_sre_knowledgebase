# Ответы — Linux Security

Стенд — VM (Ubuntu 22.04/24.04 или Debian; для упражнения 03 нужен
AppArmor, он включён в Ubuntu/Debian по умолчанию). Выводы приблизительные.

## Упражнение 01 — SUID/SGID аудит

```bash
find / -xdev \( -perm -4000 -o -perm -2000 \) -type f -exec ls -l {} + \
  2>/dev/null

PING_BIN=$(command -v ping)
ls -l "$PING_BIN"
getcap "$PING_BIN"
sysctl net.ipv4.ping_group_range

# Подозрительные SUID: интерпретаторы и редакторы с SUID = готовый root
for bin in find vim python3 perl awk nmap bash; do
    path=$(command -v "$bin") || continue
    [ -u "$path" ] && echo "ПОДОЗРИТЕЛЬНО: $path имеет SUID-бит"
done
```

Ожидаемый вывод (примерно так):

```text
-rwsr-xr-x 1 root root     72072 ... /usr/bin/passwd
-rwsr-xr-x 1 root root    277936 ... /usr/bin/sudo
-rwsr-xr-x 1 root root     55680 ... /usr/bin/su
-rwxr-sr-x 1 root shadow   31312 ... /usr/bin/chage
...
-rwxr-xr-x 1 root root 76672 ... /usr/bin/ping
(пусто или: /usr/bin/ping cap_net_raw=ep)
net.ipv4.ping_group_range = 0	2147483647
```

Почему так: `passwd`, `su`, `sudo` обязаны быть SUID — они меняют
`/etc/shadow` или UID. `ping` в современных дистрибутивах не нуждается в
SUID: либо у него `cap_net_raw`, либо ядро разрешает непривилегированные
ICMP-сокеты через `ping_group_range`. Если `ping` всё же с SUID, замена:
`sudo setcap cap_net_raw+ep "$PING_BIN" && sudo chmod u-s "$PING_BIN"`.
SUID на `find`/`vim`/`python3` — почти всегда бэкдор (техники GTFOBins).

## Упражнение 02 — SSH hardening

Правку делаем не в основном `sshd_config`, а drop-in файлом — и важно
его имя. Для большинства ключевых слов sshd использует **первое**
прочитанное значение, а `Include /etc/ssh/sshd_config.d/*.conf` стоит в
начале `sshd_config` и подключает файлы в лексикографическом порядке.
На облачных образах там уже лежит `50-cloud-init.conf` с
`PasswordAuthentication yes`, поэтому `99-hardening.conf` (и правка ниже
строки `Include` в основном файле) проиграли бы ему. Имя `00-hardening.conf`
читается первым и побеждает.

```bash
ls /etc/ssh/sshd_config.d/
grep -n '^Include' /etc/ssh/sshd_config

sudo tee /etc/ssh/sshd_config.d/00-hardening.conf >/dev/null <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
AllowUsers deploy
EOF

sudo sshd -t && echo "syntax OK"
# Итоговая конфигурация — то, что sshd реально применит
sudo sshd -T \
  | grep -Ei '^(permitrootlogin|passwordauthentication|maxauthtries|allowusers)'

# Unit называется ssh на Debian/Ubuntu и sshd на RHEL/Fedora
sudo systemctl restart ssh

# Из ВТОРОГО терминала, не закрывая текущую сессию:
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no \
    deploy@localhost
ssh deploy@localhost 'echo key auth OK'
```

Ожидаемый вывод (примерно так; `AllowUsers` — ваш пользователь):

```text
50-cloud-init.conf
12:Include /etc/ssh/sshd_config.d/*.conf
syntax OK
permitrootlogin no
passwordauthentication no
maxauthtries 3
allowusers deploy
deploy@localhost: Permission denied (publickey).
key auth OK
```

Почему так: `sshd -t` ловит синтаксис, но не порядок — только `sshd -T`
показывает победившие значения. Если там `passwordauthentication yes`,
какой-то файл с меньшим номером (или строка выше `Include`) задаёт его
раньше. `KbdInteractiveAuthentication no` закрывает вход по паролю через
keyboard-interactive/PAM. Сессию с sudo не закрывать, пока ключевой вход
не проверен, — иначе можно потерять доступ к VM.

## Упражнение 03 — AppArmor: профиль в режиме complain → enforce

```bash
sudo apt-get install -y apparmor-utils
sudo aa-status | head -3

# Тестовое «приложение»: читает /etc/hostname, пишет лог в /tmp
sudo tee /usr/local/bin/mytestapp >/dev/null <<'EOF'
#!/bin/bash
cat /etc/hostname
date >> /tmp/mytestapp.log
EOF
sudo chmod 755 /usr/local/bin/mytestapp

# Терминал 1: aa-genprof создаёт профиль в complain и ждёт
sudo aa-genprof /usr/local/bin/mytestapp
# Терминал 2: запустить приложение пару раз
/usr/local/bin/mytestapp
# Терминал 1: нажать S (scan), разрешить (A) найденные доступы, затем F

sudo aa-complain /usr/local/bin/mytestapp
/usr/local/bin/mytestapp
sudo journalctl -k | grep -i 'apparmor="ALLOWED"' | tail -5

sudo aa-enforce /usr/local/bin/mytestapp
sudo aa-status | grep mytestapp
/usr/local/bin/mytestapp            # легитимное поведение работает

# Проверка, что enforce реально блокирует: приложение лезет туда,
# чего нет в профиле
echo 'cat /etc/fstab > /dev/null' | sudo tee -a /usr/local/bin/mytestapp
/usr/local/bin/mytestapp
sudo journalctl -k | grep -i 'apparmor="DENIED"' | tail -2
```

Ожидаемый вывод (примерно так):

```text
apparmor module is loaded.
...
Setting /usr/local/bin/mytestapp to complain mode.
...
Setting /usr/local/bin/mytestapp to enforce mode.
   /usr/local/bin/mytestapp
myhost
cat: /etc/fstab: Permission denied
audit: type=1400 ... apparmor="DENIED" operation="open"
  profile="/usr/local/bin/mytestapp" name="/etc/fstab" ... requested_mask="r"
```

Почему так: complain только логирует нарушения (`ALLOWED`), поэтому на
нём профиль «обучают» на реальной нагрузке; enforce блокирует (`DENIED`).
Профиль описывает путь к бинарнику и разрешённые файлы — всё, что не
разрешено, запрещено. Профиль лежит в
`/etc/apparmor.d/usr.local.bin.mytestapp`.
Убрать после упражнения: `sudo aa-disable /usr/local/bin/mytestapp`.

## Упражнение 04 — auditd: слежка за критичным файлом

```bash
sudo auditctl -w /etc/sudoers -p wa -k sudoers_watch
sudo auditctl -w /etc/shadow -p wa -k shadow_watch
sudo auditctl -l

# Событие: изменить файл через штатный инструмент
sudo visudo        # сохранить (можно без изменений) — visudo перезапишет файл
sudo passwd -S "$USER" >/dev/null   # только чтение — НЕ событие для -p wa
sudo chage -d "$(date +%F)" "$USER" # запись в /etc/shadow — событие

sudo ausearch -k sudoers_watch -i | tail -8
sudo ausearch -k shadow_watch -i --format text | tail -3

# Постоянные правила (переживают перезагрузку)
printf '%s\n' '-w /etc/sudoers -p wa -k sudoers_watch' \
              '-w /etc/shadow -p wa -k shadow_watch' \
  | sudo tee /etc/audit/rules.d/hardening.rules
sudo augenrules --load
sudo auditctl -l
```

Ожидаемый вывод (примерно так):

```text
-w /etc/sudoers -p wa -k sudoers_watch
-w /etc/shadow -p wa -k shadow_watch
...
type=SYSCALL ... syscall=rename success=yes ... comm=visudo exe=/usr/sbin/visudo
  auid=deploy uid=root ... key=sudoers_watch
...
At 15:02:11 10/14/2026 deploy, acting as root, successfully renamed
  /etc/shadow using /usr/bin/chage
```

Почему так: `-p wa` ловит запись и смену атрибутов, но не чтение, поэтому
`visudo -c` или `passwd -S` событий не дают. `auid` (audit UID) — исходный
пользователь, вошедший в систему: он сохраняется через `sudo`, поэтому
видно, кто реально стал root. `augenrules` собирает файлы из
`/etc/audit/rules.d/` в `audit.rules`; файл `hardening.rules` перезаписан
через `tee` целиком, а не дописан, чтобы повторный запуск не плодил дубли.

## Упражнение 05 — sysctl hardening

```bash
sudo tee /etc/sysctl.d/99-hardening.conf >/dev/null <<'EOF'
kernel.randomize_va_space = 2
kernel.yama.ptrace_scope = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
EOF

sudo sysctl --system | tail -6
sysctl kernel.randomize_va_space kernel.yama.ptrace_scope \
       net.ipv4.conf.all.rp_filter net.ipv4.icmp_echo_ignore_broadcasts

# Бонус: от обычного пользователя (не root — у root есть CAP_SYS_PTRACE)
sleep 300 &
strace -p $! 2>&1 | head -2
kill %1
```

Ожидаемый вывод (примерно так):

```text
* Applying /etc/sysctl.d/99-hardening.conf ...
kernel.randomize_va_space = 2
kernel.yama.ptrace_scope = 1
...
kernel.randomize_va_space = 2
kernel.yama.ptrace_scope = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
strace: attach: ptrace(PTRACE_SEIZE, 61234): Operation not permitted
```

Почему так: в отличие от sshd, у `sysctl --system` побеждает **последнее**
значение — файлы `/etc/sysctl.d/` применяются в лексикографическом порядке,
и поздний перезаписывает ранний. Поэтому здесь префикс `99-` правильный:
он применяется после дистрибутивных `10-`/`50-`. `ptrace_scope=1`
разрешает трассировать только своих потомков: `sleep` — потомок shell, а не
`strace`, поэтому attach запрещён, хотя процесс того же пользователя.
