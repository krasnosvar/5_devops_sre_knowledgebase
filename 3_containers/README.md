# Раздел 3. Контейнеры

Docker, Podman, OCI-стандарт: как работают образы, слои, рантаймы.
Акцент — на понимании механики, а не на списке команд.

> Команды Docker/Podman → [`../1_sysadm_sre_devops_tools/.../docker/`](../../1_sysadm_sre_devops_tools/1_linux/2_services/3_containers_and_orchestration/docker/)
> и [`../podman/`](../../1_sysadm_sre_devops_tools/1_linux/2_services/3_containers_and_orchestration/podman/)

## Пререквизиты

- [1_linux_and_shell](../1_linux_and_shell/) — особенно
  [02_cgroups_and_namespaces](../1_linux_and_shell/02_cgroups_and_namespaces/),
  [04_filesystem_and_mounts](../1_linux_and_shell/04_filesystem_and_mounts/)
  и [09_linux_security](../1_linux_and_shell/09_linux_security/).
- [2_networking](../2_networking/) — особенно
  [05_iptables_and_nftables](../2_networking/05_iptables_and_nftables/)
  (NAT, на котором держится сеть Docker).

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

7. [07_dockerfile_best_practices](./07_dockerfile_best_practices/) — shell vs
   exec form, PID 1 и сигналы (graceful shutdown), ENTRYPOINT + CMD, BuildKit
   secrets и cache mounts, `.dockerignore`.

## Как проходить

01 → 02 — обязательная теория перед k8s. 03–04 — параллельно с практикой.
05 — читать перед разделом 10_devsecops. 06 — практическая основа Tier-1 лаб.
07 — после 02 (теория, практика — в упражнениях 02 и 05).

## Упражнения — минимальный тир

🐳 Все упражнения раздела работают на Tier 1 (Docker Compose).

## Когда двигаться дальше

- Можете объяснить, из каких механизмов ядра состоит контейнер и что
  делают containerd и runc.
- Можете собрать небольшой образ с правильным кэшем слоёв (multi-stage).
- Можете запустить сервис с `--cap-drop ALL`, non-root и read-only rootfs.
- Можете поднять воспроизводимый стенд на Compose с healthchecks.

Дальше: [4_kubernetes](../4_kubernetes/).
