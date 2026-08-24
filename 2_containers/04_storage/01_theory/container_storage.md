# Storage в контейнерах

## Три типа хранилища

**Volumes** — управляются Docker/containerd, хранятся вне ФС контейнера.
Живут дольше контейнера. Лучший вариант для production данных.

**Bind mounts** — монтирование директории хоста. Удобно для разработки.

**tmpfs** — только в памяти. Для временных файлов, секретов (не пишет на диск).

```bash
# Volume
docker volume create mydata
docker run -v mydata:/app/data nginx
docker volume ls
docker volume inspect mydata
docker volume rm mydata

# Bind mount
docker run -v $(pwd)/config:/app/config:ro nginx    # :ro = read-only
docker run --mount type=bind,source=$(pwd)/config,target=/app/config,readonly nginx

# tmpfs
docker run --tmpfs /tmp:size=100m,mode=1777 nginx
docker run --mount type=tmpfs,destination=/tmp,tmpfs-size=100m nginx
```

## Где хранятся данные volumes

```bash
# Docker хранит volumes в
ls /var/lib/docker/volumes/mydata/_data/

# для rootless Docker
ls $HOME/.local/share/docker/volumes/

# для Podman
ls $HOME/.local/share/containers/storage/volumes/
```

## Backup и restore volumes

```bash
# Backup: tar через временный контейнер
docker run --rm \
  -v mydata:/source:ro \
  -v $(pwd):/backup \
  alpine tar czf /backup/mydata-$(date +%Y%m%d).tar.gz -C /source .

# Restore
docker run --rm \
  -v mydata:/target \
  -v $(pwd):/backup:ro \
  alpine tar xzf /backup/mydata-20240115.tar.gz -C /target
```

## Volume drivers — внешнее хранилище

```bash
# NFS volume
docker volume create \
  --driver local \
  --opt type=nfs \
  --opt o=addr=192.168.1.100,rw \
  --opt device=:/exports/data \
  nfs-data

# docker-compose с NFS
volumes:
  nfs-data:
    driver: local
    driver_opts:
      type: nfs
      o: addr=192.168.1.100,rw,nfsvers=4
      device: ":/exports/data"
```

## Проблемы и антипаттерны

**Данные в контейнере** — исчезают при `docker rm`. Для stateful сервисов всегда volumes.

**Права доступа** — UID внутри контейнера может не совпадать с UID владельца файлов на хосте:
```bash
# контейнер запущен от root (UID 0), но файлы принадлежат UID 1000
# решение 1: указать пользователя
docker run --user 1000:1000 -v /data:/app/data myapp

# решение 2: chown внутри Dockerfile
RUN chown -R appuser:appuser /app/data

# решение 3: в k8s — fsGroup в Pod securityContext
securityContext:
  fsGroup: 1000   # все файлы будут принадлежать GID 1000
```

**SELinux/AppArmor** — на Fedora/RHEL bind mount может не работать без `:z` или `:Z`:
```bash
docker run -v /host/data:/container/data:Z nginx   # :Z = relabel для конкретного контейнера
docker run -v /host/data:/container/data:z nginx   # :z = shared между контейнерами
```
