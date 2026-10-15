#!/usr/bin/env bash
# Запуск контейнера с минимальными привилегиями
#
# Флаги (комментарии вынесены сюда: комментарий после `\` ломает перенос
# строки, и команда обрывается):
#   --read-only                      read-only rootfs
#   --cap-drop ALL + --cap-add ...   официальному nginx:alpine (master от root)
#                                    нужны только CHOWN (chown временных
#                                    каталогов) и SETUID/SETGID (переход
#                                    worker'ов на UID 101). NET_BIND_SERVICE
#                                    не нужен: Docker выставляет в контейнере
#                                    net.ipv4.ip_unprivileged_port_start=0
#   --security-opt no-new-privileges нельзя повысить привилегии (SUID)
#   seccomp                          дефолтный профиль Docker применяется сам;
#                                    свой профиль: seccomp=/path/profile.json
#   --tmpfs                          каталоги, куда nginx пишет при
#                                    read-only rootfs
#   --memory/--cpus/--pids-limit     лимиты ресурсов (cgroups)
#
# Полностью без root и без capabilities — образ
# nginxinc/nginx-unprivileged (см. ответы к упражнениям темы).
set -euo pipefail

IMAGE="nginx:alpine"

# Убрать демо-контейнер при любом исходе, в т.ч. при ошибке
trap 'docker rm -f secure-demo >/dev/null 2>&1' EXIT

docker run -d \
    --name secure-demo \
    --read-only \
    --cap-drop ALL \
    --cap-add CHOWN \
    --cap-add SETUID \
    --cap-add SETGID \
    --security-opt no-new-privileges \
    --tmpfs /var/cache/nginx:size=10m \
    --tmpfs /var/run:size=1m \
    --tmpfs /tmp:size=10m \
    --memory 128m \
    --cpus 0.5 \
    --pids-limit 50 \
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
  SecurityOpt: {{.HostConfig.SecurityOpt}}
  Memory: {{.HostConfig.Memory}}
  PidsLimit: {{.HostConfig.PidsLimit}}'

# Проверить что работает (дать nginx секунду на старт)
sleep 1
curl -sf http://localhost:8080 > /dev/null && echo "nginx responds OK"
