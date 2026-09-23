"""
Ответ: упражнение 01 — fork и exec на практике
"""
import os, time, subprocess

# 1. Fork и наблюдение
print(f"Parent PID: {os.getpid()}")

pid = os.fork()
if pid == 0:
    # Дочерний процесс
    print(f"Child PID: {os.getpid()}, Parent: {os.getppid()}")
    time.sleep(0.2)
    os._exit(0)
else:
    print(f"Parent spawned child PID: {pid}")
    os.wait()  # reap child — предотвратить zombie
    print("Child reaped, no zombie")

# 2. exec — замена образа процесса
# subprocess.run — это fork() + exec() под капотом
result = subprocess.run(["python3", "-c", "import os; print(f'exec process PID={os.getpid()}')"],
                        capture_output=True, text=True)
print(result.stdout.strip())

# 3. /proc
print(f"\nCurrent process /proc info:")
print(f"  PID: {os.getpid()}")
with open(f"/proc/{os.getpid()}/status") as f:
    for line in f:
        if any(k in line for k in ("Name:", "Pid:", "PPid:", "VmRSS:", "Threads:")):
            print(f"  {line.rstrip()}")
