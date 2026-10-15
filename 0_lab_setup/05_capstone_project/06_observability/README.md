# Шаг 6 — Observability: метрики, правила и алерты

🐳 Tier 1. Теория — [8_observability](../../../8_observability/):
[01_observability_theory](../../../8_observability/01_observability_theory/),
[02_metrics_prometheus](../../../8_observability/02_metrics_prometheus/)
(scrape, PromQL), [04_grafana](../../../8_observability/04_grafana/),
[07_alerting](../../../8_observability/07_alerting/).

Приложение уже отдаёт метрики на `/metrics` (см. `prometheus_client` в
[../app/main.py](../app/main.py)): счётчик `shortener_requests_total`
с метками `endpoint`/`status` и гистограмму
`shortener_request_duration_seconds`. На этом шаге их начинают собирать,
считать и превращать в алерты.

## Стенд

- [docker-compose.yml](docker-compose.yml) — redis + shortener (сборка из
  `../app`) + Prometheus + Grafana.
- [prometheus.yml](prometheus.yml) — scrape `shortener:8000/metrics` и
  подключение файла правил.
- [rules.yaml](rules.yaml) — пустой файл правил, его заполняете вы.
- [grafana/provisioning/datasources/prometheus.yaml](grafana/provisioning/datasources/prometheus.yaml) —
  datasource Prometheus создаётся при старте Grafana.

```bash
docker compose up -d --build
```

Prometheus — http://localhost:9090, Grafana — http://localhost:3000
(admin/admin при первом входе).

## Задание

1. Убедиться, что target `shortener` в состоянии UP (Status → Targets или
   запрос `up`). Сгенерировать трафик: несколько `POST /shorten` и
   `GET /<code>`, включая несуществующие коды.
2. Написать PromQL-запросы: RPS по эндпоинтам, доля `status="fail"` для
   `resolve`, p95 латентности `shorten`.
3. В [rules.yaml](rules.yaml) добавить recording rules для RPS и p95 и
   три алерта: приложение не скрейпится; приложение не видит Redis;
   p95 выше 500 мс. Проверить файл `promtool check rules` и перечитать
   конфиг Prometheus без рестарта.
4. В Grafana собрать дашборд из трёх панелей: RPS, доля ошибок, p95.
5. Остановить Redis (`docker compose stop redis`) и дождаться, пока
   нужный алерт перейдёт в `firing`. Вернуть Redis.
6. Вопрос на подумать: во время остановки Redis `POST /shorten` отвечает
   500. Видно ли это в `shortener_requests_total`? Почему? (К этому
   вернётся шаг 7.)

Решение — [ANSWERS.md](ANSWERS.md) и [answers/rules.yaml](answers/rules.yaml).

```bash
docker compose down -v
```
