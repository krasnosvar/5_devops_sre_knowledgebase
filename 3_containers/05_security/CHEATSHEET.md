# Безопасность контейнеров — шпаргалка

Подробности и объяснения — в
[container_security.md](./01_theory/container_security.md).
⚠️ — опасная команда или частая ловушка. PSS/PSA подробно — в
[10_devsecops/05_pod_security](../../10_devsecops/05_pod_security/).

## Слои защиты

| Механизм | Что ограничивает | По умолчанию в Docker |
| :--- | :--- | :--- |
| Capabilities | куски прав root (`NET_BIND_SERVICE`, `SYS_ADMIN`, ...) | урезанный набор, `SYS_ADMIN` нет |
| Seccomp | какие syscalls можно вызвать | профиль по умолчанию, ~40+ syscalls запрещено (`EPERM`) |
| AppArmor / SELinux (MAC) | доступ к путям и ресурсам | профиль `docker-default` / метки SELinux |
| `no-new-privileges` | повышение прав через SUID | выключен |
| User namespace / rootless | root в контейнере ≠ root на хосте | выключен (rootful dockerd) |
| read-only rootfs | запись в образ | выключен |

## docker run: безопасный запуск

| Задача | Флаг |
| :--- | :--- |
| Сбросить все capabilities, вернуть нужные | `--cap-drop ALL --cap-add NET_BIND_SERVICE` |
| Запретить SUID-эскалацию | `--security-opt no-new-privileges` |
| Свой seccomp-профиль | `--security-opt seccomp=/path/profile.json` |
| Read-only rootfs + каталоги для записи | `--read-only --tmpfs /tmp:size=10m` |
| Не root | `--user 1000:1000` |
| Лимиты (cgroups v2) | `--memory 128m --cpus 0.5 --pids-limit 50` |
| ⚠️ никогда без крайней нужды | `--privileged`, `-v /var/run/docker.sock:/var/run/docker.sock`, `--pid host`, `--cap-add SYS_ADMIN` |

## Проверка

| Задача | Команда |
| :--- | :--- |
| Capabilities процесса в контейнере | `docker run --rm alpine sh -c 'grep Cap /proc/1/status'` |
| Расшифровать маску | `capsh --decode=00000000a80425fb` |
| Флаги безопасности контейнера | `docker inspect -f '{{.HostConfig.CapDrop}} {{.HostConfig.SecurityOpt}} {{.HostConfig.ReadonlyRootfs}}' <c>` |
| Seccomp-режим процесса (2 = filter) | `grep Seccomp /proc/<pid>/status` |
| Rootless ли демон / seccomp / userns | `docker info --format '{{.SecurityOptions}}'` |
| Карта UID в user namespace | `cat /proc/<pid>/uid_map` |
| Podman rootless: маппинг UID | `podman unshare cat /proc/self/uid_map` |

## Kubernetes securityContext (профиль restricted)

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  allowPrivilegeEscalation: false   # no_new_privs
  readOnlyRootFilesystem: true      # запись — в emptyDir-тома
  capabilities:
    drop: ["ALL"]                   # add: ["NET_BIND_SERVICE"] при нужде
  seccompProfile:
    type: RuntimeDefault            # обязателен для restricted
```

| PSS-профиль | Смысл |
| :--- | :--- |
| `privileged` | без ограничений |
| `baseline` | запрещает явно опасное: privileged, hostPath, hostNetwork |
| `restricted` | non-root, drop ALL, без эскалации, seccomp `RuntimeDefault` |
| Включить на namespace | `kubectl label ns <ns> pod-security.kubernetes.io/enforce=restricted` |

## Подвохи

| ⚠️ | Суть |
| :--- | :--- |
| `USER app` в Dockerfile | не гарантия: `docker run -u 0` его переопределит — дублируйте `runAsNonRoot` |
| `runAsNonRoot` + `USER app` (имя, не UID) без `runAsUser` | kubelet не может проверить имя пользователя → под не стартует |
| Nginx «нужен root для 80 порта» | `NET_BIND_SERVICE` или слушать 8080; Docker уже ставит `ip_unprivileged_port_start=0` |
| `CAP_SYS_ADMIN` | «новый root»: mount, cgroups, namespaces |
| Доступ к `docker.sock` | = root на хосте через новый `--privileged` контейнер |
| `emptyDir` ≠ RAM | tmpfs только с `medium: Memory` |

> Проверка: флаги `docker run`, `inspect`/`info`-шаблоны, `/proc`-
> проверки и `capsh --decode` выполнены локально (Docker 29.9, Podman
> 5.8), YAML — `yamllint`; не проверено: `kubectl label` и PSA на
> кластере.
