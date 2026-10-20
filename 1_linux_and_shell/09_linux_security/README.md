# 09. Безопасность Linux

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — команды и шаблоны одним экраном.

## Зачем
securityContext в k8s, capabilities и seccomp в контейнерах, CIS-
бенчмарки и аудит хостов опираются на механизмы ОС: SUID и capabilities,
sudo/PAM, SSH hardening, SELinux/AppArmor, auditd, sysctl и systemd
sandboxing. Тема нужна, чтобы закрыть хост и уметь расследовать «кто это
сделал».

## Пререквизиты
- [01_process_model](../01_process_model/) — UID процесса, ptrace.
- [05_systemd](../05_systemd/) — unit-файлы (sandboxing-директивы).
- [10_users_and_permissions](../10_users_and_permissions/) полезно пройти
  раньше или параллельно — там учётные записи и ACL без security-фокуса.
- Стенд: 🖥 Tier 2 — VM с systemd и AppArmor/SELinux
  ([0_lab_setup/02_local_vms](../../0_lab_setup/02_local_vms/)).

## Файлы
- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: SUID, sudo, SSH, SELinux, auditd.
- [01_theory/linux_security.md](./01_theory/linux_security.md) —
  SUID/SGID/sticky, ACL, sudo и PAM, SSH hardening (включая порядок
  drop-in файлов sshd), SELinux vs AppArmor, auditd, sysctl и systemd
  sandboxing.
- [02_examples/harden_audit.sh](./02_examples/harden_audit.sh) — аудит
  security-настроек хоста только на чтение.
- [03_exercises/README.md](./03_exercises/README.md) — 5 упражнений
  (SUID-аудит, SSH, AppArmor, auditd, sysctl), 🖥 Tier 2.
- [04_exercises_answers/answers.md](./04_exercises_answers/answers.md) —
  ответы.

## Как проходить
1. Теория → `bash 02_examples/harden_audit.sh` на своей VM.
2. Упражнения 01-05 на одноразовой VM (SSH hardening может отрезать
   доступ — держите открытой вторую сессию).
3. Сверить с [ответами](./04_exercises_answers/answers.md).

## Когда двигаться дальше
- можете объяснить, почему drop-in `99-hardening.conf` для sshd может не
  сработать, и проверить итог через `sshd -T`;
- можете заменить SUID на capability и объяснить разницу;
- можете найти через `ausearch`, кто изменил `/etc/sudoers`.

Дальше: [10_users_and_permissions](../10_users_and_permissions/).
