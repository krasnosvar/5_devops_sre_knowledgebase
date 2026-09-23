"""
Ответ: упражнение 02 — zombie процесс
Ключевое: zombie создаётся когда родитель НЕ вызывает wait().
Решение: всегда вызывать os.wait() или signal.SIGCHLD handler.
"""
import os, time, signal

# Вариант 1: явный wait() — правильно
def with_wait():
    pid = os.fork()
    if pid == 0:
        print(f"[child] PID={os.getpid()} exiting")
        os._exit(0)
    else:
        time.sleep(0.5)
        # Без wait: child был бы zombie до вызова wait
        os.waitpid(pid, 0)
        print(f"[parent] Child {pid} reaped cleanly")

# Вариант 2: SIGCHLD handler — для серверов с множеством потомков
def sigchld_handler(sig, frame):
    # Reap все завершившиеся дочерние процессы
    while True:
        try:
            pid, _ = os.waitpid(-1, os.WNOHANG)
            if pid == 0:
                break
            print(f"[handler] Reaped child {pid}")
        except ChildProcessError:
            break

signal.signal(signal.SIGCHLD, sigchld_handler)

pid = os.fork()
if pid == 0:
    print(f"[child] PID={os.getpid()} exiting (SIGCHLD will reap me)")
    os._exit(0)
else:
    time.sleep(0.3)
    print("[parent] Done — SIGCHLD handler reaped child automatically")

# Почему это важно в контейнерах:
# PID 1 (init/tini/dumb-init) ДОЛЖЕН вызывать wait() для всех потомков.
# Без этого контейнер накапливает zombie процессы.
