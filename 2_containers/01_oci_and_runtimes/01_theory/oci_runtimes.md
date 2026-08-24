# OCI и container runtimes

## OCI — Open Container Initiative

Три спецификации, определяющие контейнерный стандарт:

**Image Spec** — формат образа: слои (tar), манифест (JSON с хешами слоёв),
config (environment, entrypoint, labels). Образ одинаково читается Docker,
containerd, Podman, CRI-O.

**Runtime Spec** — что такое «запущенный контейнер»: rootfs, namespaces,
cgroups, capabilities, mounts. Реализуют: runc, crun, gVisor, kata-containers.

**Distribution Spec** — протокол pull/push образов в registry.
Именно поэтому образы из Docker Hub работают в любом OCI-совместимом инструменте.

## Стек контейнерных рантаймов

```
kubelet (k8s)
    │  CRI (Container Runtime Interface) — gRPC API
    ▼
containerd                    ◄── или CRI-O (альтернатива для k8s)
    │  containerd-shim
    ▼
runc / crun                   ◄── OCI runtime (создаёт сам контейнер)
    │
    ▼
Linux kernel (namespaces + cgroups)
```

**Docker Engine** — добавляет поверх containerd: Docker API, CLI, BuildKit,
compose. В k8s Docker Engine не нужен — kubelet общается напрямую с containerd.

**containerd** — промышленный стандарт CRI. Управляет lifecycle контейнеров,
образами, снапшотами. Используется в k8s по умолчанию.

**runc** — эталонная реализация OCI runtime от Docker. Написан на Go.
**crun** — альтернатива на C, быстрее старта, меньше памяти.

## Альтернативные OCI runtimes

**gVisor** (`runsc`) — sandbox runtime: системные вызовы контейнера
перехватываются user-space ядром (ptrace или KVM). Изоляция лучше runc,
производительность ниже. Используется в Google Cloud Run.

**Kata Containers** — каждый контейнер запускается в лёгкой VM (QEMU/KVM).
Максимальная изоляция, производительность ниже, запуск медленнее.
Используется для ненадёжного кода (multi-tenant inference).

```yaml
# k8s: использовать gVisor для pod
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
---
spec:
  runtimeClassName: gvisor
```

## Podman vs Docker

| | Docker | Podman |
|---|---|---|
| Архитектура | dockerd daemon (root) | Daemonless, fork+exec |
| Rootless | Ограниченно | Нативно |
| CLI совместимость | — | `alias docker=podman` |
| Pods | Нет | Да (как в k8s) |
| Systemd интеграция | Через юниты | Нативная (Quadlets) |
| По умолчанию на | Ubuntu, Debian | RHEL, Fedora |

## Проверка runtime в k8s кластере

```bash
kubectl get nodes -o wide          # столбец CONTAINER-RUNTIME
kubectl describe node nodename | grep -i runtime

# на ноде
crictl --runtime-endpoint unix:///run/containerd/containerd.sock info
crictl ps                          # запущенные контейнеры (как docker ps)
crictl images                      # образы в containerd
```
