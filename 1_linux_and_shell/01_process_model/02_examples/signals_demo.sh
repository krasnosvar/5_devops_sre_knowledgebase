#!/usr/bin/env bash
# Демонстрация сигналов и graceful shutdown
set -euo pipefail

echo "=== Сигналы и graceful shutdown ==="

# 1. Запустить процесс и послать SIGTERM
cat > /tmp/app.py << 'PYEOF'
import signal, time, sys

def on_sigterm(sig, frame):
    print(f"[app] Got SIGTERM, cleaning up...", flush=True)
    time.sleep(0.5)
    print("[app] Done, exiting gracefully", flush=True)
    sys.exit(0)

signal.signal(signal.SIGTERM, on_sigterm)
print(f"[app] Started, PID={os.getpid()}", flush=True)

import os
print(f"[app] PID={os.getpid()}", flush=True)
while True:
    time.sleep(0.1)
PYEOF

python3 /tmp/app.py &
APP_PID=$!
sleep 0.3

echo "Sending SIGTERM to PID $APP_PID"
kill -SIGTERM $APP_PID
wait $APP_PID 2>/dev/null || true
echo "Exit code: $?"

# 2. Посмотреть /proc
echo -e "\n=== /proc информация о текущем процессе ==="
echo "PID: $$"
echo "PPID: $(cat /proc/$$/status | grep PPid | awk '{print $2}')"
echo "State: $(cat /proc/$$/status | grep 'State:' | awk '{print $2, $3}')"
echo "Threads: $(cat /proc/$$/status | grep Threads | awk '{print $2}')"
echo "VmRSS: $(cat /proc/$$/status | grep VmRSS | awk '{print $2, $3}')"
echo "Open FDs: $(ls /proc/$$/fd 2>/dev/null | wc -l)"

# 3. Fork + exec на примере
echo -e "\n=== fork+exec: каждая команда в shell ==="
echo "Shell PID: $$"
echo "bash -c 'echo \$\$' запустит: $(bash -c 'echo $$')"
echo "(это новый PID — результат fork+exec)"
