# Раздел 2. Контейнеры

Docker, Podman, OCI-стандарт: как работают образы, слои, рантаймы.
Акцент — на понимании механики, а не на списке команд.

> Команды Docker/Podman → [`../1_sysadm_sre_devops_tools/.../docker/`](../../1_sysadm_sre_devops_tools/1_linux/2_services/3_containers_and_orchestration/docker/)
> и [`../podman/`](../../1_sysadm_sre_devops_tools/1_linux/2_services/3_containers_and_orchestration/podman/)

## Подразделы

1. [01_oci_and_runtimes](./01_oci_and_runtimes/) — OCI-спецификация: image spec,
   runtime spec, distribution spec; цепочка containerd → runc → cgroups+namespaces;
   разница между Docker Engine, containerd, CRI-O, podman.

2. [02_image_layers](./02_image_layers/) — overlay FS: как слои хранятся и
   собираются в union mount; copy-on-write; почему порядок инструкций в Dockerfile
   влияет на размер и кэш; multi-stage builds и distroless.

3. [03_networking](./03_networking/) — сетевые режимы: bridge (veth + iptables NAT),
   host, none, macvlan; DNS внутри Docker; как контейнеры находят друг друга
   по имени в compose.

4. [04_storage](./04_storage/) — volumes vs bind mounts vs tmpfs; где данные
   реально хранятся; volume drivers; backup и restore данных контейнеров.

5. [05_security](./05_security/) — Linux capabilities (что теряется при `--cap-drop all`),
   seccomp профили, AppArmor/SELinux, rootless контейнеры (user namespace remapping),
   сканирование образов (Trivy); принцип наименьших привилегий в Dockerfile.

6. [06_compose_patterns](./06_compose_patterns/) — docker compose для локальной
   разработки и лабораторных стендов: healthchecks, depends_on с condition,
   profiles, override files; типовые паттерны (app + db + cache).

## Как проходить

01 → 02 — обязательная теория перед k8s. 03–04 — параллельно с практикой.
05 — читать перед разделом 9_security. 06 — практическая основа Tier-1 лаб.

## Упражнения — минимальный тир

🐳 Все упражнения раздела работают на Tier 1 (Docker Compose).
