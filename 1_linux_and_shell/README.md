# Раздел 1. Linux и Shell

Фундамент, на котором строится весь DevOps-стек. Здесь — не список команд
(они в [`../1_sysadm_sre_devops_tools/`](../../1_sysadm_sre_devops_tools/1_linux/)),
а понимание механики: почему контейнеры работают именно так, что такое cgroup
в контексте k8s limits, как systemd управляет процессами в кластерных нодах.

## Пререквизиты

- [0_lab_setup](../0_lab_setup/) — 🐳 Tier 1
  ([01_docker_compose](../0_lab_setup/01_docker_compose/)) для
  упражнений на контейнерах; для тем с systemd, cgroups, AppArmor и
  `ip netns` нужен 🖥 Tier 2
  ([02_local_vms](../0_lab_setup/02_local_vms/)).
- Уверенная работа в терминале: cd, ls, редактор, SSH-ключи.

Docker, kind и kubectl встречаются в отдельных упражнениях раньше, чем
разбираются в своих разделах, — такие места помечены «Забегание вперёд»
и их можно пропустить.

## Подразделы

0. [00_architecture_and_boot](./00_architecture_and_boot/) — user space vs kernel
   space, процесс загрузки Linux (boot process), базовые сервисы (SSH под
   капотом, NTP/chrony). Отправная точка перед процессной моделью.

1. [01_process_model](./01_process_model/) — процессная модель Linux: fork/exec,
   PID namespace, сигналы, zombie и orphan процессы, `/proc`, exit codes.
   *Почему это важно:* именно так устроен жизненный цикл контейнера.

2. [02_cgroups_and_namespaces](./02_cgroups_and_namespaces/) — cgroups v1/v2
   (CPU, memory, blkio limits) и namespaces (PID, NET, MNT, UTS, USER, IPC).
   *Почему это важно:* это буквально то, из чего сделан Docker/containerd.

3. [03_file_descriptors_and_io](./03_file_descriptors_and_io/) — файловые
   дескрипторы, stdin/stdout/stderr, pipes, named pipes, `/dev/null`, lsof;
   перенаправление и буферизация вывода в скриптах.

4. [04_filesystem_and_mounts](./04_filesystem_and_mounts/) — VFS, mount namespaces,
   bind mounts, overlay FS (как работают слои образов), tmpfs, /proc и /sys.

5. [05_systemd](./05_systemd/) — unit lifecycle, targets, socket activation,
   journald, cgroup-дерево через systemd; как k8s управляет kubelet как сервисом.

6. [06_networking_basics](./06_networking_basics/) — сеть глазами Linux-
   инструментов: `ip` (адреса, маршруты), `ss` и TIME_WAIT, `/etc/hosts`/
   nsswitch/`resolv.conf`, network namespaces и veth, базовый tcpdump.
   Протоколы (TCP, DNS, TLS, балансировка, iptables) — в
   [`../2_networking/`](../2_networking/).

7. [07_bash_for_devops](./07_bash_for_devops/) — bash-идиомы для DevOps-скриптов:
   idempotency, retry с backoff, lockfiles, trap для cleanup, heredoc, работа
   с JSON через jq; не синтаксис, а паттерны которые встречаются в реальных скриптах.

8. [08_performance_and_ebpf](./08_performance_and_ebpf/) — perf, eBPF-инструменты
   (bpftrace, bcc), профилирование CPU/IO/сети без изменения кода приложения.

9. [09_linux_security](./09_linux_security/) — права доступа (SUID/SGID/sticky bit,
   ACL), sudo и PAM, SSH hardening, SELinux vs AppArmor (MAC), auditd, kernel
   hardening через sysctl, systemd sandboxing. *Почему это важно:* это ОС-основа,
   на которой строятся securityContext в k8s и capabilities/seccomp в контейнерах —
   см. [`../3_containers/05_security/`](../3_containers/05_security/) и
   [`../4_kubernetes/06_security/`](../4_kubernetes/06_security/).

10. [10_users_and_permissions](./10_users_and_permissions/) — учётные записи и
    группы (`/etc/passwd`/`shadow`/`group`, `useradd`/`usermod`, primary vs
    supplementary группы), NSS (откуда ОС берёт пользователей — локально или
    LDAP/AD), ACL по-настоящему (default ACL, mask, POSIX vs NFSv4). Не про
    hardening (это в 09) — про то, как вообще устроены аккаунты и
    точечный доступ.

11. [11_troubleshooting](./11_troubleshooting/) — системный
    анализ инцидентов и узких мест: методологии USE/RED, 60-секундный экспресс-чек-лист,
    D-state процессы, Page Cache и Slab (`SUnreclaim`), механика OOM Killer и `oom_score_adj`,
    насыщение дискового I/O (`r_await`/`w_await`), скрытые удаленные файлы (`lsof +L1`),
    дропы в сокетных буферах и softirq, переполнение conntrack, профилирование через perf и eBPF.

## Как проходить

Идти по порядку 00 → 11: каждый следующий раздел опирается на предыдущий.
Разделы 01–02 критичны для понимания контейнеров; 06 — для понимания k8s сети;
09–10 используют знания почти всех предыдущих разделов (namespaces, systemd,
/proc, файловые права); 11 закрепляет системную диагностику всего стека.

## Когда двигаться дальше

- можете объяснить, из каких механизмов ядра (namespaces, cgroups v2,
  OverlayFS) собран контейнер, и показать каждый руками;
- можете написать unit-файл systemd и идемпотентный bash-скрипт со
  strict mode, retry и trap;
- можете по 60-секундному чек-листу определить, какой ресурс хоста
  насыщен, и найти виновный процесс.

Дальше: [2_networking](../2_networking/) — протоколы поверх
Linux-инструментов из темы 06.

## Связь с другими разделами

- Команды и утилиты → [`../1_sysadm_sre_devops_tools/1_linux/1_shell_bash_commands/`](../../1_sysadm_sre_devops_tools/1_linux/1_shell_bash_commands/)
- Скрипты-примеры → [`../1_sysadm_sre_devops_tools/1_linux/3_scripts_bash_python/`](../../1_sysadm_sre_devops_tools/1_linux/3_scripts_bash_python/)
- Современные CLI-утилиты → [`../1_sysadm_sre_devops_tools/1_linux/1_shell_bash_commands/9_modern_cli_alternatives.sh`](../../1_sysadm_sre_devops_tools/1_linux/1_shell_bash_commands/9_modern_cli_alternatives.sh)
- Git (workflow, branching/merging, conflicts — теория, примеры, упражнения) → [`../4_python_my_knowledgebase/0_tooling_and_workflow/01_git_essentials/`](../../4_python_my_knowledgebase/0_tooling_and_workflow/01_git_essentials/)
