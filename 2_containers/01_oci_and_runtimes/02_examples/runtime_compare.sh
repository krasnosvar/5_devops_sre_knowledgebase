#!/usr/bin/env bash
# Сравнить Docker и crictl (containerd) интерфейсы

echo "=== Docker Engine (высокоуровневый) ==="
docker version --format '{{.Server.Version}}' 2>/dev/null | head -1 \
    && echo "Docker: $(docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}' 2>/dev/null | head -5)" \
    || echo "(Docker недоступен)"

echo -e "\n=== containerd через crictl (k8s уровень) ==="
if command -v crictl &>/dev/null; then
    crictl --runtime-endpoint unix:///run/containerd/containerd.sock info 2>/dev/null | jq '.config.containerdEndpoint' \
        || echo "containerd endpoint не найден"
    crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps 2>/dev/null | head -5 \
        || echo "(crictl требует containerd)"
else
    echo "(crictl не установлен — нужен для k8s узла)"
fi

echo -e "\n=== OCI Runtime (runc/crun) ==="
if command -v runc &>/dev/null; then
    runc --version
else
    echo "runc: $(docker info 2>/dev/null | grep 'Default Runtime' || echo 'недоступен напрямую')"
fi

echo -e "\n=== Overlay FS (как Docker хранит слои) ==="
mount | grep overlay | head -3 \
    || echo "(нет overlay mounts — контейнеры не запущены)"

echo -e "\n=== Размер образов по слоям ==="
docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" 2>/dev/null | head -10 \
    || echo "(Docker недоступен)"
