#!/usr/bin/env bash
# Запуск контейнера с минимальными привилегиями

IMAGE="nginx:alpine"

docker run -d \
    --name secure-demo \
    --read-only \                          # read-only rootfs
    --cap-drop ALL \                       # убрать все capabilities
    --cap-add NET_BIND_SERVICE \           # только биндить порты
    --security-opt no-new-privileges \    # нельзя повысить привилегии
    --security-opt seccomp=default \      # стандартный seccomp профиль
    --user 1000:1000 \                    # non-root
    --tmpfs /var/cache/nginx:size=10m \   # tmpfs для nginx cache
    --tmpfs /var/run:size=1m \
    --tmpfs /tmp:size=10m \
    --memory 128m \                        # лимит памяти
    --cpus 0.5 \                          # лимит CPU
    --pids-limit 50 \                     # лимит процессов
    --network bridge \
    -p 8080:80 \
    "$IMAGE"

echo "Container started: $(docker inspect secure-demo --format '{{.Id}}' | head -c 12)"
echo "Security options:"
docker inspect secure-demo --format '
  ReadOnly: {{.HostConfig.ReadonlyRootfs}}
  User: {{.Config.User}}
  CapAdd: {{.HostConfig.CapAdd}}
  CapDrop: {{.HostConfig.CapDrop}}
  Memory: {{.HostConfig.Memory}}
  PidsLimit: {{.HostConfig.PidsLimit}}'

# Проверить что работает
curl -sf http://localhost:8080 > /dev/null && echo "nginx responds OK"

docker rm -f secure-demo
