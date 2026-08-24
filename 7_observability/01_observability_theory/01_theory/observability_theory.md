# Observability — теория

## Observability vs Monitoring

**Monitoring** — знаешь заранее что проверять. Дашборды, пороговые алерты.
Хорошо когда знакомые проблемы. Плохо для новых, неизвестных отказов.

**Observability** — способность понять внутреннее состояние системы
по её внешним выходам (метрики, логи, трейсы), даже для проблем которые
ты не предвидел.

## Три столпа

| Столп | Что даёт | Когда использовать |
|-------|----------|-------------------|
| **Metrics** | Агрегированные числа во времени | «Что происходит?» — rate, errors, latency |
| **Logs** | Детальные события с контекстом | «Почему это произошло?» — конкретный запрос, ошибка |
| **Traces** | Путь запроса через микросервисы | «Где узкое место?» — распределённые системы |

Они дополняют, не заменяют друг друга.

## Методологии метрик

### RED (для сервисов принимающих запросы)

| Метрика | Что измеряет |
|---------|-------------|
| **R**ate | Количество запросов в секунду |
| **E**rrors | Количество/доля ошибок |
| **D**uration | Время ответа (latency) |

```promql
# Rate запросов
rate(http_requests_total[5m])

# Error rate
rate(http_requests_total{status=~"5.."}[5m])
  / rate(http_requests_total[5m])

# 95-й перцентиль latency
histogram_quantile(0.95,
  sum by (le)(rate(http_request_duration_seconds_bucket[5m]))
)
```

### USE (для ресурсов — CPU, память, диски)

| Метрика | Что измеряет |
|---------|-------------|
| **U**tilization | Использование ресурса (%) |
| **S**aturation | Насколько ресурс перегружен (очередь) |
| **E**rrors | Ошибки ресурса |

```promql
# CPU Utilization
100 - avg by(instance)(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100

# Memory Saturation (swap usage)
rate(node_vmstat_pswpin[5m]) + rate(node_vmstat_pswpout[5m])

# Disk Errors
rate(node_disk_io_time_weighted_seconds_total[5m])
```

### Google Four Golden Signals

Для production сервисов (из SRE Book):

1. **Latency** — время обработки запроса (успешных И ошибочных — ошибки тоже могут быть медленными)
2. **Traffic** — нагрузка на систему (RPS, connections, queries/sec)
3. **Errors** — частота отказов (явные 500, неявные — медленные 200 с неверными данными)
4. **Saturation** — насколько система заполнена (CPU, mem, disk, network)

## SLO-based alerting vs threshold alerting

### Threshold alerting (традиционный, плохой)
```yaml
# Алертит при кратковременных спайках, пропускает медленные деградации
alert: HighErrorRate
expr: rate(http_errors_total[1m]) > 0.01
```

Проблемы:
- Много false positives (кратковременный всплеск → алерт, но пользователи не пострадали)
- Много false negatives (медленное ухудшение не достигает порога)
- Не учитывает бюджет ошибок

### Burn rate alerting (SLO-based, лучший)

```yaml
# SLO: 99.9% success rate за 30 дней
# Алертит когда ошибки сжигают error budget слишком быстро

# Быстрый огонь: 14.4x burn rate за 1 час = потратим весь бюджет за 2 дня
alert: ErrorBudgetBurnRateFast
expr: |
  (rate(http_errors_total[1h]) / rate(http_requests_total[1h]))
  > (14.4 * 0.001)   # 14.4x * (1 - SLO)
for: 2m

# Медленный огонь: 6x burn rate за 6 часов
alert: ErrorBudgetBurnRateSlow
expr: |
  (rate(http_errors_total[6h]) / rate(http_requests_total[6h]))
  > (6 * 0.001)
for: 15m
```

## Correlation — связывание трёх столпов

Правильный workflow расследования инцидента:

```
1. Алерт (metrics): error rate вырос до 5%
   ↓
2. Grafana dashboard (metrics): видно с какого момента и на каком сервисе
   ↓
3. Loki (logs): фильтр по времени и сервису → конкретные ошибки
   ↓
4. Tempo (traces): trace ID из лога → полный путь запроса через микросервисы
   ↓
5. Найден root cause: timeout на базе данных в сервисе payments
```

Связывание: поле `trace_id` в логах → прямая ссылка в Grafana на trace.
