# Упражнения — HTTP и TLS

Стенд: 🐳 Tier 1 — nginx в Docker Compose

```bash
cd ../02_examples
./gen-cert.sh          # сгенерировать self-signed сертификат
docker compose up -d
```

## 01 — Убедиться, что соединение реально HTTP/2 + TLS 1.3

```bash
curl -sk --http2 -I https://localhost:8443/
openssl s_client -connect localhost:8443 -tls1_3 </dev/null 2>/dev/null | grep -E "Protocol|Cipher"
# TODO: почему без флага -k (--insecure) curl откажется подключаться?
```

## 02 — ETag и 304 Not Modified

**Задача:** Получить ETag, переспросить с `If-None-Match`, убедиться в `304` без тела.

```bash
ETAG=$(curl -sk https://localhost:8443/ -D - -o /dev/null | grep -i etag | tr -d '\r' | sed 's/.*: //')
curl -sk https://localhost:8443/ -H "If-None-Match: $ETAG" -D - -o /dev/null
# TODO: измени html/index.html, повтори запрос с тем же старым ETag — должен вернуться 200, не 304
```

## 03 — Ловушка nginx: add_header и наследование

**Задача:** Убрать `add_header Cache-Control` из `location /` и добавить туда же `add_header X-Debug test` — убедиться, что `Cache-Control` пропадает из ответа, даже если вернуть его на уровень `server`.

```bash
# TODO: в nginx.conf добавь в location / ещё одну строку:
#   add_header X-Debug "test";
# оставь add_header Cache-Control тоже в location (не убирай) —
# сравни поведение, когда обе директивы на одном уровне (должно работать),
# и когда Cache-Control передвинут на уровень server, а X-Debug остался в location
docker compose restart nginx
curl -sk https://localhost:8443/ -D - -o /dev/null
```

## 04 — HTTP → HTTPS редирект

```bash
curl -sI http://localhost:8080/
# TODO: какой код ответа? Куда указывает заголовок Location?
```
