#!/usr/bin/env bash
# Ответ: упражнение 01 — nginx с минимальными capabilities
# Проблема: nginx нужен NET_BIND_SERVICE для порта 80
# Решение: drop ALL + add NET_BIND_SERVICE + порт > 1024 не требует capabilities

echo "=== Вариант 1: drop ALL + NET_BIND_SERVICE (порт 80) ==="
docker run -d --name nginx-secure-1 \
    --cap-drop ALL \
    --cap-add NET_BIND_SERVICE \
    --security-opt no-new-privileges \
    --read-only \
    --tmpfs /var/cache/nginx:size=10m \
    --tmpfs /var/run:size=1m \
    -p 8080:80 \
    nginx:alpine

sleep 1
curl -sf http://localhost:8080 > /dev/null && echo "✓ Работает с NET_BIND_SERVICE"
docker rm -f nginx-secure-1

echo -e "\n=== Вариант 2: порт 8080 не требует NET_BIND_SERVICE ==="
# Порт > 1024 — не нужен NET_BIND_SERVICE
cat > /tmp/nginx-unprivileged.conf << 'EOF'
server {
    listen 8080;
    location / { return 200 "ok\n"; }
}
EOF

docker run -d --name nginx-secure-2 \
    --cap-drop ALL \
    --security-opt no-new-privileges \
    --read-only \
    --tmpfs /var/cache/nginx:size=10m \
    --tmpfs /var/run:size=1m \
    --user 101:101 \
    -v /tmp/nginx-unprivileged.conf:/etc/nginx/conf.d/default.conf:ro \
    -p 8081:8080 \
    nginxinc/nginx-unprivileged:alpine

sleep 1
curl -sf http://localhost:8081 && echo "✓ Работает без capabilities"
docker rm -f nginx-secure-2
rm /tmp/nginx-unprivileged.conf

echo -e "\n=== Ответ: лучшая практика ==="
echo "1. Использовать nginxinc/nginx-unprivileged (слушает 8080, не root)"
echo "2. drop ALL capabilities — NET_BIND_SERVICE не нужен для порта > 1024"
echo "3. --read-only + tmpfs для /var/cache/nginx, /var/run"
