import fakeredis
from fastapi.testclient import TestClient

import main

main.r = fakeredis.FakeRedis(decode_responses=True)
client = TestClient(main.app)


def test_health():
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


def test_shorten_and_resolve():
    resp = client.post("/shorten", json={"url": "https://example.com"})
    assert resp.status_code == 200
    code = resp.json()["code"]

    resp = client.get(f"/{code}", follow_redirects=False)
    assert resp.status_code in (302, 307)
    assert resp.headers["location"] == "https://example.com"


def test_shorten_without_url():
    resp = client.post("/shorten", json={})
    assert resp.status_code == 400


def test_resolve_unknown_code():
    resp = client.get("/does-not-exist")
    assert resp.status_code == 404
