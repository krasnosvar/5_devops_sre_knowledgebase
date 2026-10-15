# Минимальное Flask-приложение для full-stack.yaml.
# GET /  — счётчик визитов в Redis + версия PostgreSQL: видно, что app
#          реально ходит в обе зависимости по именам сервисов compose.
import os

import psycopg2
import redis
from flask import Flask

app = Flask(__name__)
cache = redis.Redis.from_url(os.environ["REDIS_URL"])


@app.get("/")
def index():
    visits = cache.incr("visits")
    conn = psycopg2.connect(os.environ["DATABASE_URL"])
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT version()")
            pg_version = cur.fetchone()[0]
    finally:
        conn.close()
    return {"visits": visits, "postgres": pg_version}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
