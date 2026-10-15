# Ответы — шаг 7 (SRE)

Задание — [README.md](README.md). Стенд — из
[../06_observability](../06_observability/) с правилами из его
`answers/rules.yaml`.

## 1. SLI и SLO

- **SLI доступности:** доля пользовательских запросов (`/shorten`,
  `/<code>`), ответивших не 5xx. 404 на неизвестный код и 400 без `url` —
  ошибки клиента, они не тратят бюджет. `/health` и `/metrics` — служебный
  трафик, в SLI не входят.
- **SLI латентности:** доля запросов `/<code>` быстрее 100 мс.
- **SLO:** 99.5% доступности за скользящие 30 дней.
- **Error budget:** 0.5% запросов; при равномерном трафике это
  `30 × 24 × 60 × 0.005 = 216` минут полного простоя в месяц.

Почему так: SLO формулируют от пользователя (что он видит), а не от
процесса (жив ли контейнер). Детали выбора SLI — в
[9_sre/01_slo_sli_sla](../../../9_sre/01_slo_sli_sla/).

## 2. Game day

```bash
cd ../06_observability/
cp answers/rules.yaml rules.yaml
docker compose up -d --build
while true; do
  curl -s -o /dev/null -w '%{http_code}\n' -X POST http://localhost:8000/shorten \
    -H 'content-type: application/json' -d '{"url":"https://example.com"}'
  sleep 1
done > /tmp/gameday-codes.txt &
date -u +%T; docker compose stop redis
sleep 300
date -u +%T; docker compose start redis
sleep 30
kill %1
sort /tmp/gameday-codes.txt | uniq -c
curl -s http://localhost:8000/metrics | grep 'shortener_requests_total{endpoint="shorten"'
```

Ожидаемый вывод (примерно так):

```text
10:00:00
10:05:00
    300 200
    270 500
shortener_requests_total{endpoint="shorten",status="ok"} 300.0
```

Таймлайн (примерно): 10:00 Redis остановлен → сразу 500 у пользователей;
~10:01:30 `ShortenerRedisUnavailable` в `firing` (через `/health`);
10:05 Redis запущен → 200; алерт гаснет через ~2 минуты.

Почему так: пользователь видел 270 ошибок, а в
`shortener_requests_total` их нет вовсе. Алерт сработал только потому, что
`/health` проверяет Redis, — на ошибки самих пользовательских запросов
никакого сигнала не было. Это и есть главный вывод game day.

## 3. Постмортем (пример)

```text
Постмортем: недоступность сокращения ссылок (game day)

Влияние: 5 минут, ~47% запросов POST /shorten за период теста вернули 500.
         Редирект /<code> тоже недоступен (Redis — единственное хранилище).
Обнаружение: алерт ShortenerRedisUnavailable через ~1.5 мин.
Таймлайн (UTC):
  10:00:00  Redis остановлен (сценарий game day)
  10:01:30  ShortenerRedisUnavailable → firing
  10:05:00  Redis запущен, ответы 200
  10:07:00  алерт resolved
Корневая причина: Redis — единственная точка отказа без реплики;
  приложение не обрабатывает ошибки Redis и отдаёт 500.
Что сработало: health-check зависимостей в /health и алерт на нём.
Что не сработало: метрики приложения не учитывают 5xx — по дашборду
  ошибок не видно; SLI посчитать нельзя.
Action items:
  1. Метрика ответов по HTTP-коду + SLO burn-rate алерты (владелец: dev, P1)
  2. Обрабатывать redis.RedisError и отвечать 503 вместо 500 (dev, P2)
  3. Redis с репликой / persistent storage в k8s (platform, P3)
```

Почему так: blameless-формат фиксирует системные причины и действия, а не
виноватых; у каждого action item есть владелец и приоритет. Шаблон —
[9_sre/04_postmortem](../../../9_sre/04_postmortem/).

## 4. Action item: метрика по HTTP-коду и SLO-алерты

Добавить в конец `../app/main.py`:

```python
HTTP_RESPONSES = Counter(
    "shortener_http_responses_total", "HTTP responses by status code", ["code"]
)


@app.middleware("http")
async def count_responses(request, call_next):
    if request.url.path in ("/metrics", "/health"):
        return await call_next(request)
    try:
        response = await call_next(request)
    except Exception:
        HTTP_RESPONSES.labels("500").inc()
        raise
    HTTP_RESPONSES.labels(str(response.status_code)).inc()
    return response
```

Правила SLI/SLO — [answers/slo-rules.yaml](answers/slo-rules.yaml):
recording rules доли 5xx на окнах 5m/30m/1h/6h и два multi-window
burn-rate алерта (14.4x — critical, 6x — warning).

```bash
cd ../06_observability/
cat answers/rules.yaml ../07_sre_incident/answers/slo-rules.yaml \
  | grep -v '^groups:' | sed '1i groups:' > rules.yaml
docker compose up -d --build
docker compose exec prometheus promtool check rules /etc/prometheus/rules.yaml
docker compose stop redis
curl -s -o /dev/null -w '%{http_code}\n' -X POST http://localhost:8000/shorten \
  -H 'content-type: application/json' -d '{"url":"https://x.org"}'
curl -s http://localhost:8000/metrics | grep shortener_http_responses_total
docker compose start redis
```

Ожидаемый вывод (примерно так):

```text
Checking /etc/prometheus/rules.yaml
  SUCCESS: 11 rules found
500
# HELP shortener_http_responses_total HTTP responses by status code
# TYPE shortener_http_responses_total counter
shortener_http_responses_total{code="500"} 1.0
```

Почему так: middleware видит каждый ответ, включая необработанные
исключения, поэтому SLI больше не зависит от того, не забыл ли автор
`inc()` в какой-то ветке. Multi-window burn rate (длинное окно + короткое)
даёт быстрый алерт на сильный сбой и не шумит после его окончания —
подробно в [9_sre/02_error_budget_policy](../../../9_sre/02_error_budget_policy/).
