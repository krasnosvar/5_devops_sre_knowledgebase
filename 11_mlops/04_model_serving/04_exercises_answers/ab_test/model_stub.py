"""Заглушка модели для лабы A/B: отвечает на POST /predict и
возвращает версию из переменной окружения MODEL_VERSION.

Настоящая модель (BentoML-сервис из упражнения 02) здесь не нужна:
упражнение проверяет разделение трафика, а не качество предсказаний.
"""
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

VERSION = os.environ["MODEL_VERSION"]  # без значения по умолчанию


class Handler(BaseHTTPRequestHandler):
    def do_POST(self) -> None:
        if self.path != "/predict":
            self.send_error(404)
            return
        length = int(self.headers["Content-Length"])
        # невалидный JSON -> исключение, соединение рвётся, nginx вернёт 502
        json.loads(self.rfile.read(length))
        body = json.dumps({"prediction": [0], "version": VERSION}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


HTTPServer(("0.0.0.0", 3000), Handler).serve_forever()
