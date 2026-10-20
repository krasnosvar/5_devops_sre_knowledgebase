# OCI и container runtimes — шпаргалка

Подробности и объяснения — в [oci_runtimes.md](./01_theory/oci_runtimes.md).
⚠️ — опасная команда или частая ловушка.

## Цепочка запуска

| Уровень | Docker | Kubernetes | Podman |
| :--- | :--- | :--- | :--- |
| Клиент / оркестратор | `docker` CLI → `dockerd` | `kubelet` | `podman` (без демона) |
| High-level runtime (CRI) | `containerd` | `containerd` или CRI-O (gRPC CRI) | — |
| Родитель процесса контейнера | `containerd-shim` | `containerd-shim` / `conmon` (CRI-O) | `conmon` |
| Low-level OCI runtime | `runc` | `runc` / `crun` / `runsc` / `kata` | `crun` или `runc` |

## Какой low-level runtime

| Runtime | Что это | Когда |
| :--- | :--- | :--- |
| `runc` | Go, стандарт по умолчанию | всё обычное |
| `crun` | C, быстрее, меньше RAM | Podman, плотная упаковка |
| `runsc` (gVisor) | ядро в user space перехватывает syscalls | недоверенный код, multi-tenant |
| Kata Containers | microVM со своим ядром на контейнер | изоляция уровня VM |

## Docker / Podman

| Задача | Команда |
| :--- | :--- |
| Runtime по умолчанию и доступные | `docker info --format '{{.DefaultRuntime}} {{json .Runtimes}}'` |
| Драйвер и версия cgroups | `docker info --format '{{.CgroupDriver}} v{{.CgroupVersion}}'` |
| PID контейнера на хосте | `docker inspect -f '{{.State.Pid}}' <c>` |
| Дерево процессов: shim → PID 1 | `ps -ef --forest \| grep -A2 containerd-shim` |
| Версия runc / crun | `runc --version` / `crun --version` |
| Runtime у Podman | `podman info --format '{{.Host.OCIRuntime.Name}}'` |
| Запустить с другим runtime | `docker run --rm --runtime=runsc alpine dmesg` (runsc должен быть зарегистрирован) |

## containerd / CRI (на ноде Kubernetes)

| Задача | Команда |
| :--- | :--- |
| Контейнеры / поды через CRI | `crictl ps` / `crictl pods` |
| Образы через CRI | `crictl images` |
| Детали контейнера | `crictl inspect <id>` |
| Явно указать сокет | `crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps` |
| Низкоуровнево (namespace k8s) | `ctr -n k8s.io containers list` |
| Перезапустить containerd (контейнеры живут благодаря shim) | `sudo systemctl restart containerd` |
| Контейнеры переживают рестарт `dockerd` | `/etc/docker/daemon.json`: `{ "live-restore": true }` |

## RuntimeClass (Kubernetes)

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc          # имя handler'а в конфиге containerd/CRI-O
---
# в Pod: spec.runtimeClassName: gvisor
```

## Подвохи

| ⚠️ | Суть |
| :--- | :--- |
| «k8s отказался от Docker» | убран только dockershim (1.24); образы из `docker build` — OCI, работают |
| `runc` не висит в фоне | создаёт контейнер и выходит; родитель — shim |
| `kill -9 <host-pid>` | PID 1 контейнера убивается с хоста, PID namespace не защищает |
| `--privileged` для DinD | снимает seccomp/AppArmor, отдаёт все capabilities и `/dev` |
| `ps aux` в контейнере | видит только свой PID namespace (свой `procfs`) |

> Проверка: `docker info`/`inspect` форматы, `podman info`, `runc`/`crun
> --version`, `ctr --help` проверены локально (Docker 29.9, Podman
> 5.8); не проверено: `crictl` (нет на хосте), `--runtime=runsc`,
> RuntimeClass в кластере.
