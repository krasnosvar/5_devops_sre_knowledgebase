"""Минимальное приложение для Dockerfile.optimized: python -m src.main."""
from flask import Flask

app = Flask(__name__)


@app.get("/")
def index():
    return "Hello from optimized image!\n"


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
