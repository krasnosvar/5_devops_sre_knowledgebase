# Балансировка нагрузки — шпаргалка

Подробности и объяснения — в
[load_balancing.md](./01_theory/load_balancing.md). ⚠️ — опасная команда или
частая ловушка.

## L4 vs L7

| | L4 | L7 |
| :--- | :--- | :--- |
| Видит | IP, порт (5-tuple) | HTTP: путь, `Host`, заголовки, cookie |
| Соединения | пакеты перекладываются как есть | два TCP: клиент↔LB и LB↔backend |
| Умеет | распределять соединения | роутинг по пути/хосту, A/B, TLS termination, ретраи |
| Цена | минимальный overhead | терминация TCP/TLS, парсинг HTTP |
| Примеры | IPVS, AWS NLB, HAProxy `mode tcp`, nginx `stream` | nginx `http`, Envoy, HAProxy `mode http`, AWS ALB |

## Алгоритмы (когда что)

| Алгоритм | nginx | Когда |
| :--- | :--- | :--- |
| Round Robin | по умолчанию | одинаковые короткие запросы |
| Weighted | `server ... weight=3;` | разные по мощности backend'ы |
| Least Connections | `least_conn;` | долгие/неравномерные запросы |
| IP Hash | `ip_hash;` | грубая привязка клиента к backend |
| Consistent hashing | `hash $request_uri consistent;` | кэширующие backend'ы, пул меняется: перетасовка ~1/N ключей |

⚠️ `hash(ip) % N` без consistent при изменении N перекидывает почти всех
клиентов — кэш backend'ов «остывает» целиком.

## nginx: upstream и health checks

```nginx
upstream backend {
    least_conn;
    server 10.0.0.1:8080 weight=3 max_fails=2 fail_timeout=10s;
    server 10.0.0.2:8080 max_fails=2 fail_timeout=10s;
    server 10.0.0.3:8080 backup;
    keepalive 32;                       # пул соединений к backend'ам
}
server {
    listen 80;
    location / {
        proxy_pass http://backend;
        proxy_http_version 1.1;         # нужно для keepalive
        proxy_set_header Connection "";
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_next_upstream error timeout http_502 http_503;
        proxy_connect_timeout 2s;
    }
}
```

| Задача | Команда / директива |
| :--- | :--- |
| Проверить конфиг | `nginx -t` |
| Применить без обрыва соединений | `nginx -s reload` |
| Пассивный health check | `max_fails` (по умолчанию 1) / `fail_timeout` (по умолчанию 10s) |
| Активный health check | open-source nginx не умеет; HAProxy `option httpchk`, Envoy, облачный LB |
| Вывести из ротации | `server ... down;` + reload |
| Детерминированная лаба на малом трафике | `worker_processes 1;` |
| Проверить распределение | `for i in $(seq 10); do curl -s localhost/; done \| sort \| uniq -c` |

## Health checks

| Тип | Как работает | Ловушка |
| :--- | :--- | :--- |
| Активный | LB сам опрашивает `/healthz` по расписанию | ⚠️ `/healthz`, проверяющий БД, выводит из ротации все backend'ы сразу |
| Пассивный | LB считает ошибки реального трафика | замечает сбой только после ошибок клиентов |

Правило: health check проверяет сам процесс (жив и готов), а не цепочку
зависимостей.

## Sticky sessions

| Вариант | Комментарий |
| :--- | :--- |
| Сессия во внешнем store (Redis) | ✅ backend'ы stateless, sticky не нужен |
| Cookie affinity (HAProxy `cookie`, ALB stickiness) | ⚠️ падение/rolling update backend'а = потеря сессий, перекос нагрузки |
| `ip_hash` | ⚠️ клиенты за одним NAT лягут на один backend |

## Reverse proxy vs load balancer

| Роль | Что делает | backend'ов |
| :--- | :--- | :--- |
| Reverse proxy | TLS termination, кэш, сжатие, заголовки | ≥ 1 |
| Load balancer | распределение по алгоритму | ≥ 2 |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| «Всё идёт на один backend» на малом трафике | счётчики per-worker: `worker_processes 1` для проверки |
| `502 Bad Gateway` | backend не слушает/упал: `error.log`, `ss -tlnp` на backend |
| `504 Gateway Timeout` | backend медленный: `proxy_read_timeout`, логи backend |
| Весь пул выпал разом | health check зависит от общей зависимости |
| Клиенту нужен реальный IP | `X-Forwarded-For` (L7) или PROXY protocol (L4) |

> Проверка: конфиг-снипет прошёл `nginx -t` в `nginx:alpine`; дефолты
> `max_fails`/`fail_timeout` — по документации nginx; не проверено: HAProxy и
> ALB-настройки (нет локально).
