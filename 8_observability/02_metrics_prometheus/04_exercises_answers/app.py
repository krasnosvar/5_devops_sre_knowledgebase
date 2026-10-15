"""Ответ к упражнению 04: HTTP-сервер с метриками Prometheus.

Запуск:
    pip install prometheus_client
    python app.py
Приложение: http://localhost:8001/ (и /error — отвечает 500)
Метрики:    http://localhost:8000/metrics
"""

import random
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

from prometheus_client import Counter, Histogram, start_http_server

REQUESTS = Counter(
    "http_requests_total",
    "Количество HTTP-запросов",
    ["method", "path", "status"],
)
LATENCY = Histogram(
    "http_request_duration_seconds",
    "Длительность обработки запроса",
    ["path"],
)


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        start = time.perf_counter()
        time.sleep(random.uniform(0.01, 0.2))  # имитация работы
        status = 500 if self.path == "/error" else 200
        self.send_response(status)
        self.end_headers()
        self.wfile.write(b"ok\n" if status == 200 else b"error\n")
        LATENCY.labels(path=self.path).observe(time.perf_counter() - start)
        REQUESTS.labels(method="GET", path=self.path, status=str(status)).inc()

    def log_message(self, fmt, *args):  # не засорять stdout
        pass


if __name__ == "__main__":
    start_http_server(8000)  # отдельный порт для /metrics
    HTTPServer(("0.0.0.0", 8001), Handler).serve_forever()
