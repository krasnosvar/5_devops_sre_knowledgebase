import os
import random
import string
import time

from fastapi import FastAPI, HTTPException
from fastapi.responses import PlainTextResponse, RedirectResponse
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
import redis

REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))

app = FastAPI(title="shortener")
r = redis.Redis(
    host=REDIS_HOST,
    port=REDIS_PORT,
    decode_responses=True,
    socket_connect_timeout=2,
)

ALPHABET = string.ascii_letters + string.digits

REQUESTS = Counter("shortener_requests_total", "Total requests", ["endpoint", "status"])
LATENCY = Histogram("shortener_request_duration_seconds", "Request latency", ["endpoint"])


def new_code(length: int = 6) -> str:
    return "".join(random.choices(ALPHABET, k=length))


@app.get("/health")
def health():
    try:
        r.ping()
    except redis.RedisError:
        REQUESTS.labels("health", "fail").inc()
        raise HTTPException(status_code=503, detail="redis unavailable")
    REQUESTS.labels("health", "ok").inc()
    return {"status": "ok"}


@app.get("/metrics")
def metrics():
    return PlainTextResponse(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.post("/shorten")
def shorten(payload: dict):
    start = time.time()
    url = payload.get("url")
    if not url:
        REQUESTS.labels("shorten", "fail").inc()
        raise HTTPException(status_code=400, detail="url is required")

    code = new_code()
    r.set(f"url:{code}", url)

    LATENCY.labels("shorten").observe(time.time() - start)
    REQUESTS.labels("shorten", "ok").inc()
    return {"code": code, "short_url": f"/{code}"}


@app.get("/{code}")
def resolve(code: str):
    start = time.time()
    url = r.get(f"url:{code}")
    LATENCY.labels("resolve").observe(time.time() - start)

    if not url:
        REQUESTS.labels("resolve", "fail").inc()
        raise HTTPException(status_code=404, detail="not found")

    REQUESTS.labels("resolve", "ok").inc()
    return RedirectResponse(url)
