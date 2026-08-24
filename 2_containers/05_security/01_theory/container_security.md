# Безопасность контейнеров

## Linux capabilities — гранулярные привилегии

root в Linux имеет набор capabilities. Контейнеры по умолчанию запускаются
с подмножеством capabilities, а не с полным root.

```bash
# capabilities контейнера по умолчанию (Docker)
# CAP_CHOWN, CAP_DAC_OVERRIDE, CAP_FOWNER, CAP_FSETID,
# CAP_KILL, CAP_NET_BIND_SERVICE, CAP_SETGID, CAP_SETUID,
# CAP_SYS_CHROOT, CAP_MKNOD, CAP_NET_RAW, ...

# минимальный безопасный запуск
docker run --cap-drop ALL --cap-add NET_BIND_SERVICE nginx

# посмотреть capabilities процесса
cat /proc/1/status | grep Cap
capsh --decode=00000000a80425fb    # декодировать hex в названия
```

```yaml
# k8s: capabilities в securityContext
securityContext:
  capabilities:
    drop: ["ALL"]
    add: ["NET_BIND_SERVICE"]
```

**Опасные capabilities:**
- `CAP_SYS_ADMIN` — почти root, открывает mount, ptrace и многое другое
- `CAP_NET_ADMIN` — изменение сетевых настроек хоста
- `CAP_SYS_PTRACE` — отлаживать любой процесс на хосте

## Seccomp — фильтрация syscalls

Seccomp (SECure COMPuting) ограничивает системные вызовы которые
может делать процесс. Docker применяет default профиль (~300 разрешённых syscalls).

```bash
# запустить с профилем (убирает опасные syscalls)
docker run --security-opt seccomp=default.json nginx

# запустить без seccomp (опасно, только для отладки)
docker run --security-opt seccomp=unconfined nginx
```

```yaml
# k8s
securityContext:
  seccompProfile:
    type: RuntimeDefault    # профиль по умолчанию containerd/cri-o
```

## Rootless контейнеры — user namespace remapping

Без rootless: root в контейнере = root на хосте (если сбежит из контейнера).
С rootless: root в контейнере → UID 100000 на хосте.

```bash
# Podman — rootless по умолчанию
podman run nginx               # запускается как ваш UID

# Docker rootless mode
dockerd-rootless-setuptool.sh install
export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
docker run nginx               # root в контейнере = ~UID 100000 на хосте
```

```yaml
# k8s: запретить root
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
```

## Read-only filesystem

```bash
# контейнер не может изменять свою ФС
docker run --read-only nginx
# ОШИБКА: nginx нужны /var/run, /var/cache/nginx

docker run --read-only \
  --tmpfs /var/run \
  --tmpfs /var/cache/nginx \
  nginx
```

```yaml
# k8s
securityContext:
  readOnlyRootFilesystem: true
volumeMounts:
  - name: tmp
    mountPath: /tmp
volumes:
  - name: tmp
    emptyDir: {}
```

## Сканирование образов на CVE

```bash
# Trivy (рекомендуется)
trivy image nginx:latest
trivy image --severity HIGH,CRITICAL nginx:latest
trivy image --exit-code 1 --severity CRITICAL nginx:latest  # fail в CI

# в CI (GitLab):
trivy-scan:
  image: aquasec/trivy
  script:
    - trivy image --exit-code 1 --severity HIGH,CRITICAL $IMAGE

# Grype (альтернатива)
grype nginx:latest
```

## Полный securityContext для production pod

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      securityContext:                  # уровень Pod
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: app
          securityContext:              # уровень Container
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
```

## Основные принципы

1. Никогда не запускать как root без явной необходимости
2. Drop ALL capabilities, добавлять только нужные
3. Использовать minimal base images (distroless, alpine, scratch)
4. Сканировать образы перед деплоем в CI
5. `readOnlyRootFilesystem: true` + `tmpfs` для временных файлов
6. Не хранить секреты в ENV или в образе — использовать Vault/External Secrets
