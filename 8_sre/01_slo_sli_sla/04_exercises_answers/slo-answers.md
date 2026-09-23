# Ответы: SLO / SLI / SLA упражнения

## Упражнение 01 — Определить SLI и SLO

```
Сервис 1: API (POST /orders)
  SLI: доля запросов завершившихся с HTTP 2xx за последние 30 дней
  SLO: 99.9% (допускает 43 мин downtime в месяц)

Сервис 2: Batch job платежей (ночной)
  SLI: доля батчей обработанных полностью в течение 4 часов
  SLO: 99.5% (1 пропущенный батч из 200 = OK)

Сервис 3: S3-хранилище файлов
  SLI: доля PUT/GET запросов завершённых с latency < 500ms
  SLO: 99.95% доступности + 99.999999999% durability

Сервис 4: WebSocket уведомления
  SLI: доля соединений установленных в течение 2 секунд
  SLO: 99% (реалтайм — пользователи терпимы к редким задержкам)
```

## Упражнение 02 — PromQL для SLO 99.9%

```promql
# 1. Текущий error rate за 30 дней
rate(http_requests_total{status=~"5.."}[30d])
/ rate(http_requests_total[30d])

# 2. Остаток error budget (1.0 = полный, 0.0 = исчерпан)
1 - (
  rate(http_requests_total{status=~"5.."}[30d])
  / rate(http_requests_total[30d])
) / 0.001

# 3. Burn rate за последний час
(
  rate(http_requests_total{status=~"5.."}[1h])
  / rate(http_requests_total[1h])
) / 0.001
# > 1.0 = тратим быстрее нормы
# > 14.4 = бюджет сгорит за 2 дня (critical alert)

# 4. Когда закончится при текущей скорости (дней)
30 / (
  (rate(http_requests_total{status=~"5.."}[1h])
   / rate(http_requests_total[1h]))
  / 0.001
)
```

## Упражнение 03 — SLO Dashboard в Grafana

```
Панель 1: Error Budget Remaining %
  Expr: (1 - (rate(http_requests_total{status=~"5.."}[30d])
              / rate(http_requests_total[30d])) / 0.001) * 100
  Тип: Gauge | Min: 0 | Max: 100
  Thresholds: 10=red, 25=orange, 50=yellow, 100=green

Панель 2: Burn Rate (последние 7 дней)
  Expr: (rate(http_requests_total{status=~"5.."}[1h])
         / rate(http_requests_total[1h])) / 0.001
  Тип: Time series | Reference line: y=1 (нормальная скорость)

Панель 3: MTTR (последние 30 дней)
  # Из Alertmanager или внешней системы через recording rules
  avg_over_time(alertmanager_alert_duration_seconds[30d])
```

## Упражнение 04 — Burn rate alerts

```yaml
groups:
  - name: slo-alerts
    rules:
      - alert: ErrorBudgetBurnFast
        expr: |
          (rate(http_requests_total{status=~"5.."}[1h])
           / rate(http_requests_total[1h])) > 14.4 * 0.001
        for: 2m
        labels: {severity: critical}
        annotations:
          summary: "Error budget burning fast (2 days to exhaustion)"

      - alert: ErrorBudgetBurnSlow
        expr: |
          (rate(http_requests_total{status=~"5.."}[6h])
           / rate(http_requests_total[6h])) > 6 * 0.001
        for: 15m
        labels: {severity: warning}
        annotations:
          summary: "Error budget burning (5 days to exhaustion)"
```
