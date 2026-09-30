# Упражнения — DNS

Стенд: 🐳 Tier 1 — CoreDNS в Docker Compose

```bash
cd ../02_examples
docker compose up -d
```

## 01 — Прямой запрос к своему authoritative-серверу

**Задача:** Спросить CoreDNS напрямую (в обход системного резолвера) про записи из зоны.

```bash
dig @127.0.0.1 -p 15353 www.example.com A
dig @127.0.0.1 -p 15353 api.example.com CNAME
dig @127.0.0.1 -p 15353 example.com MX
dig @127.0.0.1 -p 15353 example.com TXT
# TODO: сравни TTL в ответе с $TTL в example.com.db
```

## 02 — CNAME resolution chain

**Задача:** Убедиться, что `api.example.com` (CNAME на `www.example.com`) резолвится в конечном счёте в тот же IP.

```bash
dig @127.0.0.1 -p 15353 api.example.com +noall +answer
# TODO: в выводе должно быть 2 записи — CNAME и A. Объясни почему обе появляются в одном ответе.
```

## 03 — Изменить TTL и понаблюдать за кэшированием

**Задача:** Изменить `$TTL` в `example.com.db` на `3600`, перезапустить CoreDNS, убедиться что новый TTL отражается в ответах.

```bash
# TODO: поправь $TTL 60 -> $TTL 3600 в zones/example.com.db
docker compose restart coredns
dig @127.0.0.1 -p 15353 www.example.com +noall +answer
# TODO: сравни поле TTL в ответе до и после правки
```

## 04 — TXT-запись как верификация владения доменом

**Задача:** Добавить TXT-запись `_acme-challenge.example.com` (как это делает Let's Encrypt DNS-01 challenge) и убедиться что она резолвится.

```bash
# TODO: добавь в example.com.db строку:
#   _acme-challenge  IN  TXT  "some-random-token-value"
docker compose restart coredns
dig @127.0.0.1 -p 15353 _acme-challenge.example.com TXT +short
```
