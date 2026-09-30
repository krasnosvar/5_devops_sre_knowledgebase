# Упражнения — Linux Security

Стенд: 🖥 Tier 2 — нужна полноценная VM (KVM / OrbStack / VirtualBox), не Docker:
SELinux/AppArmor и правка `sshd_config` с рестартом сервиса требуют настоящего
ядра и systemd в качестве PID 1. Упражнение 01 (SUID-аудит) работает и в 🐳 Tier 1.

## 01 — SUID/SGID аудит

**Задача:** Найти все SUID/SGID бинарники на хосте и оценить, какие из них реально нужны.

```bash
find / -xdev \( -perm -4000 -o -perm -2000 \) -type f 2>/dev/null

# Для каждого найденного бинарника ответь:
# - действительно ли обычному пользователю нужно запускать его с повышенными правами?
# - есть ли альтернатива без SUID (capabilities вместо полного root)?

# Пример: ping часто использует SUID, но может обойтись capability
getcap /usr/bin/ping
# TODO: если у ping есть SUID, но capabilities не используются — предложи убрать SUID
# и выдать точечную capability через setcap
```

## 02 — SSH hardening

**Задача:** Привести `sshd_config` к безопасному состоянию и убедиться, что сервис не сломался.

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# TODO: добавить/поправить в /etc/ssh/sshd_config
#   PermitRootLogin ???
#   PasswordAuthentication ???
#   MaxAuthTries ???
#   AllowUsers ??? (свой пользователь)

sudo sshd -t                        # проверить синтаксис ДО рестарта — обязательно!
sudo systemctl restart sshd

# Проверить с другого терминала, что вход по паролю запрещён,
# а по ключу — работает (не закрывай текущую sudo-сессию, пока не проверишь!)
ssh -o PreferredAuthentications=password localhost   # должно быть отклонено
```

## 03 — AppArmor: профиль в режиме complain → enforce

**Задача:** Сгенерировать профиль для простого бинарника, посмотреть на что он ругается, включить enforce.

```bash
# Установить (если не установлено) и проверить статус
sudo aa-status

# Сгенерировать черновик профиля для тестового скрипта
sudo aa-genprof /usr/local/bin/mytestapp
# в другом терминале — запусти mytestapp и поделай что он обычно делает,
# aa-genprof предложит разрешить/запретить каждое обнаруженное действие

# Включить режим наблюдения (не блокирует, только логирует)
sudo aa-complain /usr/local/bin/mytestapp
sudo journalctl -k | grep -i apparmor | tail -20

# TODO: когда убедился что легитимные действия не блокируются — включить enforce
sudo aa-enforce /usr/local/bin/mytestapp
```

## 04 — auditd: слежка за критичным файлом

**Задача:** Настроить аудит изменений `/etc/sudoers` и `/etc/shadow`, найти событие в логе.

```bash
sudo auditctl -w /etc/sudoers -p wa -k sudoers_watch
sudo auditctl -w /etc/shadow -p wa -k shadow_watch

# Спровоцировать событие
sudo visudo    # просто открыть и сохранить без изменений тоже считается

# TODO: найти событие через ausearch по ключу
sudo ausearch -k sudoers_watch

# Сделать правило постоянным (переживает перезагрузку)
echo "-w /etc/sudoers -p wa -k sudoers_watch" | sudo tee -a /etc/audit/rules.d/hardening.rules
sudo augenrules --load
```

## 05 — sysctl hardening

**Задача:** Применить набор hardening-параметров через `/etc/sysctl.d/`, проверить что применились.

```bash
# TODO: создать /etc/sysctl.d/99-hardening.conf с параметрами
# kernel.randomize_va_space, kernel.yama.ptrace_scope,
# net.ipv4.conf.all.rp_filter, net.ipv4.icmp_echo_ignore_broadcasts

sudo sysctl --system

# Проверить что применилось
sysctl kernel.randomize_va_space kernel.yama.ptrace_scope

# Бонус: проверить, что ptrace_scope=1 реально мешает
# (после этого второй процесс того же пользователя не сможет strace процесс-не-потомок)
strace -p $(pgrep -u "$USER" -n bash) 2>&1 | head -3
```
