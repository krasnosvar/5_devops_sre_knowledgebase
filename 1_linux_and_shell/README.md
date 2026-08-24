# Раздел 1. Linux и Shell

Фундамент, на котором строится весь DevOps-стек. Здесь — не список команд
(они в [`../1_sysadm_sre_devops_tools/`](../../1_sysadm_sre_devops_tools/1_linux/)),
а понимание механики: почему контейнеры работают именно так, что такое cgroup
в контексте k8s limits, как systemd управляет процессами в кластерных нодах.

## Подразделы

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

6. [06_networking_basics](./06_networking_basics/) — сетевой стек Linux: netfilter,
   iptables/nftables, veth pairs, bridges, routing. Фундамент для понимания
   k8s networking (CNI, kube-proxy, Services).

7. [07_bash_for_devops](./07_bash_for_devops/) — bash-идиомы для DevOps-скриптов:
   idempotency, retry с backoff, lockfiles, trap для cleanup, heredoc, работа
   с JSON через jq; не синтаксис, а паттерны которые встречаются в реальных скриптах.

## Как проходить

Идти по порядку 01 → 07: каждый следующий раздел опирается на предыдущий.
Разделы 01–02 критичны для понимания контейнеров; 06 — для понимания k8s сети.

## Связь с другими разделами

- Команды и утилиты → [`../1_sysadm_sre_devops_tools/1_linux/1_shell_bash_commands/`](../../1_sysadm_sre_devops_tools/1_linux/1_shell_bash_commands/)
- Скрипты-примеры → [`../1_sysadm_sre_devops_tools/1_linux/3_scripts_bash_python/`](../../1_sysadm_sre_devops_tools/1_linux/3_scripts_bash_python/)
- Современные CLI-утилиты → [`../1_sysadm_sre_devops_tools/1_linux/1_shell_bash_commands/9_modern_cli_alternatives.sh`](../../1_sysadm_sre_devops_tools/1_linux/1_shell_bash_commands/9_modern_cli_alternatives.sh)
