#!/usr/bin/env bash
# Ответ: упражнение 03 — cgroups memory limit и OOM killer
# Ключевое: limits.memory → cgroup memory.max → OOMKill при превышении

echo "=== Создаём cgroup с лимитом 50MB ==="
CGROUP_PATH="/sys/fs/cgroup/mytest-$$"
sudo mkdir -p "$CGROUP_PATH"
echo "52428800" | sudo tee "$CGROUP_PATH/memory.max" > /dev/null   # 50 MB
echo "0" | sudo tee "$CGROUP_PATH/memory.swap.max" > /dev/null     # без swap
echo "Лимит установлен: $(cat $CGROUP_PATH/memory.max) bytes"

echo -e "\n=== Запускаем процесс в cgroup ==="
# cgexec помещает процесс в cgroup
sudo cgexec -g memory:mytest-$$ python3 -c "
import time, sys
data = []
try:
    for i in range(200):
        data.append(b'x' * 1024 * 1024)   # +1 MB
        print(f'Allocated {i+1} MB', flush=True)
        time.sleep(0.05)
except MemoryError:
    print(f'MemoryError at {len(data)} MB', flush=True)
    sys.exit(1)
" 2>&1 || echo "Process killed by OOM killer (exit code $?)"

echo -e "\n=== OOM events в cgroup ==="
cat "$CGROUP_PATH/memory.events" 2>/dev/null

# Очистка
sudo rmdir "$CGROUP_PATH" 2>/dev/null || true

echo -e "\n=== Связь с k8s: OOMKilled ==="
echo "k8s: limits.memory → memory.max в cgroup"
echo "При превышении: OOM killer → exit code 137 (128+9=SIGKILL)"
echo "kubectl describe pod: LastState.Reason=OOMKilled"
