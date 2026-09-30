# SRE в действии — сквозной практический пример

SRE — это практика, а не набор команд. Лучший способ понять её — проследить
полный цикл на конкретном сервисе: от определения SLO до инцидента и постмортема.

## Стенд

Используй Prometheus + Grafana из [8_observability/02_metrics_prometheus/02_examples/](../8_observability/02_metrics_prometheus/02_examples/):

```bash
cd ../8_observability/02_metrics_prometheus/02_examples/
docker compose up -d
```

---

## Шаг 1 — Определить SLO для HTTP API

Допустим, у нас есть API сервис. Договариваемся внутри команды:

```
Сервис: Payment API (POST /v1/payments)
SLI: доля успешных запросов (HTTP 2xx от общего числа)
SLO: 99.9% за 30-дневное скользящее окно
Error budget: 0.1% × 30 дней × 24 ч × 60 мин = 43.2 минуты
```

Записать в README сервиса и в wiki — это договор команды.

## Шаг 2 — Настроить SLO метрики в Prometheus

Добавить в `prometheus.yml` (или через recording rules) запросы для отслеживания:

```yaml
# slo_rules.yml
groups:
  - name: payment-api-slo
    interval: 30s
    rules:
      # Текущий error rate за 30 дней (скользящее окно)
      - record: job:payment_errors:rate30d
        expr: |
          rate(http_requests_total{job="payment-api", status=~"5.."}[30d])
          / rate(http_requests_total{job="payment-api"}[30d])

      # Остаток error budget: 1.0 = полный, 0.0 = исчерпан
      - record: job:payment_error_budget:remaining
        expr: |
          1 - (job:payment_errors:rate30d / 0.001)
```

```promql
# Проверить в Prometheus Expression Browser:
# http://localhost:9090/graph

# Текущий остаток бюджета (%)
(1 - job:payment_errors:rate30d / 0.001) * 100

# Burn rate за последний час (1.0 = нормальная скорость)
rate(http_requests_total{job="payment-api", status=~"5.."}[1h])
/ rate(http_requests_total{job="payment-api"}[1h])
/ 0.001
```

## Шаг 3 — Настроить burn rate алерты

```yaml
# alerts/slo.yml
groups:
  - name: payment-api-slo
    rules:
      # Критический алерт: бюджет сгорит за 2 дня (14.4x burn rate за 1 час)
      - alert: PaymentAPIErrorBudgetBurnCritical
        expr: |
          (
            rate(http_requests_total{job="payment-api",status=~"5.."}[1h])
            / rate(http_requests_total{job="payment-api"}[1h])
          ) > (14.4 * 0.001)
        for: 2m
        labels:
          severity: critical
          service: payment-api
        annotations:
          summary: "Error budget burning fast — 2 days to exhaustion"
          runbook: "https://wiki/runbooks/payment-api-errors"

      # Warning: бюджет сгорит за 5 дней (6x burn rate за 6 часов)
      - alert: PaymentAPIErrorBudgetBurnWarning
        expr: |
          (
            rate(http_requests_total{job="payment-api",status=~"5.."}[6h])
            / rate(http_requests_total{job="payment-api"}[6h])
          ) > (6 * 0.001)
        for: 15m
        labels:
          severity: warning
          service: payment-api
```

```bash
# Применить:
curl -X POST http://localhost:9090/-/reload

# Проверить в Alertmanager:
# http://localhost:9093
```

## Шаг 4 — Grafana дашборд для SLO

В Grafana (http://localhost:3000) создать дашборд с панелями:

| Панель | Тип | Запрос |
|--------|-----|--------|
| Error Budget Remaining | Gauge (0-100%) | `job:payment_error_budget:remaining * 100` |
| Burn Rate (1h) | Stat | `(rate(http_requests_total{status=~"5.."}[1h]) / rate(http_requests_total[1h])) / 0.001` |
| Error Rate Over Time | Time series | `rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])` |
| Request Rate | Time series | `sum(rate(http_requests_total[5m]))` |

Настроить пороги на Gauge:
- 0-25%: красный (feature freeze)
- 25-50%: жёлтый (reliability sprint)
- 50-100%: зелёный (нормальный режим)

## Шаг 5 — Симуляция инцидента

```bash
# Симулировать нагрузку на тестовый сервис
# (в реальности это ваши пользователи или load тест)

# Генерировать ошибки чтобы сработал burn rate алерт:
# заменить nginx на образ который возвращает 500
kubectl set image deployment/myapp app=hashicorp/http-echo:latest -- \
  -text="error" -status=500   # если в k8s

# или через docker (для локального теста):
docker run -d -p 8081:8080 hashicorp/http-echo:latest -text="Server Error" -status=500
```

**Наблюдать:**
1. Prometheus → Graph: burn rate растёт
2. Alertmanager → алерт срабатывает через 2 минуты
3. Slack/Email (если настроен): приходит уведомление
4. Grafana → Gauge краснеет

## Шаг 6 — Реакция на инцидент (по шаблону)

```
14:03 UTC — Alertmanager: PaymentAPIErrorBudgetBurnCritical
14:05 UTC — On-call открывает #incident-2024-01-15
14:05 UTC — Первое сообщение в канале:
  "SEV-2. Payment API error rate 8% (SLO: 0.1%).
   Investigating. Next update in 15 min."

14:08 UTC — Проверить что изменилось:
  kubectl rollout history deployment/payment-api
  # → выяснили что 14:01 был деплой v2.3.1

14:12 UTC — Решение: откатить
  kubectl rollout undo deployment/payment-api
  
14:17 UTC — Error rate начал снижаться
14:22 UTC — Всё ok, алерт resolved

14:22 UTC — Сообщение в канале:
  "RESOLVED. Rollback to v2.3.0 successful.
   Root cause: memory leak in v2.3.1.
   Downtime: 19 min. Postmortem tomorrow 10:00 UTC."
```

## Шаг 7 — Подсчёт потраченного error budget

```promql
# Сколько бюджета потрачено за инцидент (19 минут):
# Если за это время error rate был ~8%:
# Потрачено = 8% × 19 мин = 1.52 минуты "ошибочного времени"
# Месячный бюджет = 43.2 минуты
# Потрачено = 1.52 / 43.2 = 3.5% бюджета за один инцидент

# В Prometheus: посмотреть реальное потребление
increase(http_requests_total{status=~"5.."}[1h]) /
increase(http_requests_total[1h]) * 100
```

## Шаг 8 — Постмортем (упрощённый)

```markdown
# Postmortem: Payment API Downtime 2024-01-15

**Duration:** 19 min | **Budget consumed:** ~3.5%

**Root Cause:** Memory leak в v2.3.1 (N+1 запрос в функции логирования)

**What went well:**
- Алерт сработал через 2 мин после начала
- Rollback выполнен за 5 мин

**Action Items:**
1. Добавить метрику db_queries_per_transaction → алерт при N+1
2. Увеличить staging нагрузку до 50% от prod
3. Code review checklist: EXPLAIN ANALYZE для новых queries
```

---

## Что показывает этот пример

1. **SLO → Error Budget**: цифры переведены в конкретное время. Команда понимает что означает "потратить 3.5% бюджета".
2. **Burn rate алерт**: срабатывает на симптом (быстрый рост ошибок), а не на threshold (ошибки > X%).
3. **Incident → Postmortem**: каждый инцидент улучшает систему через action items.
4. **Упражнения к теме** → в остальных разделах базы (k8s troubleshooting — `3_kubernetes/09_cluster_operations/`, Prometheus — `7_observability/02_metrics_prometheus/03_exercises/`, Grafana — `7_observability/04_grafana/`).
