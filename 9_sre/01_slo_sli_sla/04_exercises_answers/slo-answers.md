# Ответы: SLO / SLI / SLA

Стенд и генератор трафика (~2% ошибок) — см.
[03_exercises/README.md](../03_exercises/README.md). Метрика —
`http_requests_total{job="myapp", status=...}` из демо-сервера
`app.py`.

## Упражнение 01 — Определить SLI и SLO

Это упражнение на бумаге — команд нет. Вариант ответа:

```text
Сервис 1: API для мобильного приложения (POST /orders)
  SLI: доля запросов без 5xx И быстрее 500 мс (за 30 дней)
  SLO: 99.9% (бюджет ~43 мин «плохого времени» в месяц)

Сервис 2: Batch job обработки платежей (ночной)
  SLI: доля запусков, обработавших все записи до дедлайна (06:00)
  SLO: 99% запусков за квартал (≈ 1 опоздание из 90)

Сервис 3: S3-совместимое хранилище файлов
  SLI доступности: доля успешных PUT/GET (без 5xx)
  SLI latency: доля GET объектов < 1 МБ быстрее 200 мс
  SLO: 99.95% доступности; 99% по latency
  (durability — отдельное обещание, измеряется не запросами)

Сервис 4: Realtime WebSocket уведомления
  SLI: доля уведомлений, доставленных клиенту быстрее 2 с с момента
       события; плюс доля успешных установок соединения
  SLO: 99% (realtime-канал, но пропуск редкого уведомления не критичен)
```

Почему так: SLI выбирают по тому, что видит пользователь: для
request-based сервисов — доступность и latency, для batch — свежесть
и полнота (запрос как единица не подходит), для storage — ещё и
durability, для streaming — задержка доставки. SLO ниже 100% и ниже, чем
у зависимостей.

## Упражнение 02 — PromQL для SLO

```promql
# 1. Текущий error rate за 30 дней
sum(rate(http_requests_total{job="myapp", status=~"5.."}[30d]))
/ sum(rate(http_requests_total{job="myapp"}[30d]))

# 2. Остаток error budget (1 = полный, 0 = исчерпан, < 0 = перерасход)
1 - (
  sum(rate(http_requests_total{job="myapp", status=~"5.."}[30d]))
  / sum(rate(http_requests_total{job="myapp"}[30d]))
) / 0.001

# 3. Burn rate за последний час
(
  sum(rate(http_requests_total{job="myapp", status=~"5.."}[1h]))
  / sum(rate(http_requests_total{job="myapp"}[1h]))
) / 0.001

# 4. Через сколько дней закончится бюджет при текущем burn rate
30 / (
  (
    sum(rate(http_requests_total{job="myapp", status=~"5.."}[1h]))
    / sum(rate(http_requests_total{job="myapp"}[1h]))
  ) / 0.001
)
```

Ожидаемый вывод (примерно так, при генераторе с ~2% ошибок):

```text
1. 0.02
2. -19
3. 19.7
4. 1.52
```

Почему так: burn rate = текущий error rate / допустимый (1 − SLO). При
2% ошибок и бюджете 0.1% burn rate ≈ 20, и 30-дневный бюджет сгорает
за 30 / 20 = 1.5 дня. На свежем стенде окно `[30d]` фактически содержит
только минуты данных, поэтому п.1-2 совпадают с текущим error rate.
`sum` нужен, чтобы сложить серии по `status`/`path` до деления.

## Упражнение 03 — SLO Dashboard в Grafana

```text
Панель 1: Error Budget Remaining %
  Expr: (1 - (sum(rate(http_requests_total{job="myapp", status=~"5.."}[30d]))
              / sum(rate(http_requests_total{job="myapp"}[30d]))) / 0.001) * 100
  Тип: Gauge | Min: 0 | Max: 100
  Thresholds: 0=red, 25=yellow, 50=green

Панель 2: Burn Rate (time range: Last 7 days)
  Expr: (sum(rate(http_requests_total{job="myapp", status=~"5.."}[1h]))
         / sum(rate(http_requests_total{job="myapp"}[1h]))) / 0.001
  Тип: Time series | Threshold line: 1 (нормальная скорость), 14.4 (fast burn)

Панели 3-4 (MTTR, последние инциденты) — в лабе заменены на:
  Expr: ALERTS{alertstate="firing", alertname=~"ErrorBudget.*"}
  Тип: Table | Format: Table, Type: Instant
```

Проверка, что метрика `ALERTS` есть, когда алерт firing:

```bash
curl -sG localhost:9090/api/v1/query \
  --data-urlencode 'query=ALERTS{alertstate="firing"}' \
  | jq -r '.data.result[].metric.alertname'
```

Ожидаемый вывод (примерно так):

```text
ErrorBudgetBurnFast
```

Почему так: MTTR и список инцидентов — это данные процесса (когда
объявлен инцидент, когда восстановлен), а не метрики сервиса;
Prometheus их не хранит. В реальности источник — система управления
инцидентами (её API или datasource в Grafana); метрика `ALERTS`
показывает только текущее состояние правил.

## Упражнение 04 — Burn rate alerts

Готовый файл — [slo-alerts.yml](./slo-alerts.yml).

```bash
cd 8_observability/02_metrics_prometheus/02_examples/
cp ../../../9_sre/01_slo_sli_sla/04_exercises_answers/slo-alerts.yml alerts/slo.yml
docker compose exec prometheus promtool check rules /etc/prometheus/alerts/slo.yml
curl -X POST http://localhost:9090/-/reload
# запустить генератор трафика, подождать ~3-4 минуты
curl -s localhost:9090/api/v1/alerts \
  | jq -c '.data.alerts[] | {name: .labels.alertname, state: .state}'
curl -s localhost:9093/api/v2/alerts | jq -r '.[].labels.alertname'
```

Ожидаемый вывод (примерно так):

```text
  SUCCESS: 2 rules found
{"name":"ErrorBudgetBurnFast","state":"firing"}
{"name":"ErrorBudgetBurnSlow","state":"pending"}
ErrorBudgetBurnFast
```

Почему так: при burn rate ≈ 20 оба условия истинны сразу, но быстрый
алерт ждёт `for: 2m`, а медленный — `for: 15m`, поэтому через 3-4 минуты
первый уже firing и виден в Alertmanager, второй ещё pending. В
продакшне используют multiwindow-вариант (длинное окно И короткое,
например `[1h]` и `[5m]`), чтобы алерт быстрее гас после исправления;
политика реакции на burn rate — в
[02_error_budget_policy](../../02_error_budget_policy/). Полный
набор recording/alerting rules для одного сервиса — в
[02_examples/slo-rules.yaml](../02_examples/slo-rules.yaml).
