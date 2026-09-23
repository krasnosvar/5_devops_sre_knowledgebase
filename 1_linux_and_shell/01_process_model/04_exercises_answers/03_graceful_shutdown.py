"""
Ответ: упражнение 03 — graceful shutdown через SIGTERM
"""
import signal, time, sys, os

class GracefulApp:
    def __init__(self):
        self.running = True
        self.in_flight = 0
        signal.signal(signal.SIGTERM, self._handle_sigterm)
        signal.signal(signal.SIGINT, self._handle_sigterm)

    def _handle_sigterm(self, sig, frame):
        print(f"\n[app] Signal {sig} received, starting graceful shutdown...", flush=True)
        self.running = False

    def handle_request(self, req_id: int):
        self.in_flight += 1
        time.sleep(0.1)   # имитация работы
        self.in_flight -= 1

    def run(self):
        print(f"[app] PID={os.getpid()} running. Send SIGTERM to stop.", flush=True)
        req = 0
        while self.running:
            self.handle_request(req)
            req += 1
            if req % 10 == 0:
                print(f"[app] Processed {req} requests", flush=True)
            time.sleep(0.05)

        # Graceful shutdown: ждём завершения in-flight запросов
        deadline = time.time() + 30
        print(f"[app] Waiting for {self.in_flight} in-flight requests...", flush=True)
        while self.in_flight > 0 and time.time() < deadline:
            time.sleep(0.1)

        print(f"[app] Shutdown complete after {req} requests", flush=True)
        sys.exit(0)

if __name__ == "__main__":
    GracefulApp().run()

# Тест:
#   python3 graceful_shutdown.py &
#   PID=$!
#   sleep 1
#   kill -SIGTERM $PID
#   wait $PID; echo "Exit: $?"
#
# Результат: exit code 0, все in-flight запросы завершены
