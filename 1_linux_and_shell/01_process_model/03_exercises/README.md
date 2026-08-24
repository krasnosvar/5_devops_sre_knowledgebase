# Упражнения — Process Model

Все упражнения выполняются в обычном Linux терминале. Нужен: bash, ps, kill, python3.

## 01 — fork и exec на практике

```bash
# Посмотреть как bash fork'ает дочерние процессы
bash -c "echo child PID=$$; sleep 60" &
CHILD_PID=$!

# В другом терминале:
ps aux | grep sleep
pstree -p $$   # дерево текущего shell

# Убить потомка
kill $CHILD_PID
```

## 02 — Zombie процесс

```python
# zombie.py — создать zombie намеренно
import os, time

pid = os.fork()
if pid > 0:
    # Родитель — НЕ вызывает wait(), дочерний становится zombie
    print(f"Parent PID: {os.getpid()}, child PID: {pid}")
    print("Child will become zombie in 2 seconds...")
    time.sleep(2)
    # Посмотреть zombie:
    # ps aux | grep Z
    # ps -p <child_pid> -o pid,stat,cmd
    time.sleep(10)   # дать время посмотреть
else:
    # Дочерний — завершается немедленно
    print(f"Child PID {os.getpid()} exiting")
    os._exit(0)
```

```bash
python3 zombie.py &
sleep 3
ps aux | grep -E 'zombie|defunct'
# Должен быть процесс в статусе Z (zombie)
```

## 03 — Сигналы: SIGTERM vs SIGKILL

```python
# graceful.py — обрабатывать SIGTERM правильно
import signal, time, sys

def handle_sigterm(signum, frame):
    print("Received SIGTERM, cleaning up...")
    time.sleep(1)   # имитация cleanup
    print("Cleanup done, exiting gracefully")
    sys.exit(0)

signal.signal(signal.SIGTERM, handle_sigterm)
print(f"PID: {os.getpid()}, waiting for signals...")

while True:
    time.sleep(0.1)
```

```bash
python3 graceful.py &
PID=$!

# Послать SIGTERM — приложение должно завершиться gracefully
kill -SIGTERM $PID
wait $PID
echo "Exit code: $?"

# Запустить снова, попробовать SIGKILL
python3 graceful.py &
PID=$!
kill -SIGKILL $PID   # обработчик НЕ вызывается
```

## 04 — /proc — читать информацию о процессе

```bash
# Запустить долгоживущий процесс
sleep 3600 &
PID=$!

# Читать из /proc
cat /proc/$PID/status | grep -E 'Name|Pid|PPid|State|VmRSS'
cat /proc/$PID/cmdline | tr '\0' ' '
ls -la /proc/$PID/fd | wc -l   # открытые fd
cat /proc/$PID/maps | head -10  # карта памяти

# Сравнить с ps
ps -p $PID -o pid,ppid,stat,vsz,rss,cmd

kill $PID
```
