# Capacity Planning — шпаргалка

Подробности и объяснения — в
[capacity_planning.md](./01_theory/capacity_planning.md). ⚠️ — частая
ловушка.

## Формулы

| Что | Формула | Пример |
| :--- | :--- | :--- |
| Закон Литтла | `L = λ × W` | 100 req/s × 0.05 s = 5 запросов одновременно |
| Нужная параллельность | `воркеров >= λ × W` | при 1000 req/s и 200ms — минимум 200 |
| Утилизация | `U = λ / μ` (μ — пропускная способность) | 700 / 1000 req/s = 70% |
| Запас (headroom) | `1 - пик / предел` | пик 1000, предел 1500 → 33% |
| Сложный рост | `load × (1 + g)^months` | 1000 × 1.15^6 ≈ 2313 RPS |
| Месяцев до предела | `ln(предел / load) / ln(1 + g)` | ln(1.5)/ln(1.15) ≈ 2.9 мес |
| Линейный тренд | `дней = (порог - b) / k / 86400` | `k, b = np.polyfit(ts, y, 1)` |
| Нод с запасом N+2 | `ceil(нужно_ресурса / ресурс_ноды) + 2` | 10 нод нагрузки → 12 |

⚠️ При U → 100% очередь и latency растут нелинейно — целитесь в
60–70% CPU.

## Целевые значения

| Ресурс | Цель | Почему |
| :--- | :--- | :--- |
| CPU | 60–70% | запас на пики и отказ ноды |
| Memory | 70–80% | память не «сжимается»: выше — OOM |
| Ноды | N+2 | кластер переживает потерю 2 нод |
| Диск | алерт задолго до 100% | resize/закупка занимает дни-недели |
| Масштабирование | горизонтальное предпочтительнее | без даунтайма, лимит не в размере машины |

## PromQL для трендов

| Метрика | Запрос |
| :--- | :--- |
| CPU по инстансам | `avg by (instance) (1 - rate(node_cpu_seconds_total{mode="idle"}[1h]))` |
| Память | `1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes` |
| Диск | `1 - node_filesystem_avail_bytes / node_filesystem_size_bytes` |
| Нагрузка, RPS | `sum(rate(http_requests_total[1h]))` |
| Рост БД, ГБ/день | `deriv(pg_database_size_bytes{datname="mydb"}[7d]) * 86400 / 1024^3` |
| Когда кончится диск (через 30 дней < 0?) | `predict_linear(node_filesystem_avail_bytes[7d], 30 * 86400) < 0` |

`deriv` — наклон линейной регрессии gauge в единицах/сек;
`predict_linear` — значение через N секунд по той же регрессии.

## Load testing (k6)

| Задача | Команда / синтаксис |
| :--- | :--- |
| Запуск | `k6 run load-test.js` |
| Переопределить VU и время | `k6 run --vus 50 --duration 5m load-test.js` |
| Порог p95 | `http_req_duration: ['p(95)<500']` |
| Порог ошибок | `http_req_failed: ['rate<0.01']` |
| Ступени нагрузки | `stages: [{ duration: '2m', target: 100 }, ...]` |

⚠️ `'p95<500'` — ошибка парсинга, нужно `'p(95)<500'`.
Смотреть, на какой ступени начинает расти latency и появляются ошибки —
это предел системы.

## Автомасштабирование

| Задача | Команда / snippet |
| :--- | :--- |
| HPA по CPU | `kubectl autoscale deployment myapp --cpu=70% --min=3 --max=50` |
| HPA по CPU и памяти | `kubectl autoscale deployment myapp --cpu=60% --memory=70% --min=3 --max=10` |
| Состояние HPA | `kubectl get hpa` / `kubectl describe hpa myapp` |
| По внешней метрике (очередь, RPS) | KEDA `ScaledObject` |

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: myapp-scaler
spec:
  scaleTargetRef:
    name: myapp
  minReplicaCount: 3
  maxReplicaCount: 100
  triggers:
    - type: prometheus
      metadata:
        serverAddress: http://prometheus:9090
        query: sum(rate(http_requests_total[2m]))
        threshold: "100"   # целевое значение на реплику
```

⚠️ `--cpu-percent` в `kubectl autoscale` устарел — `--cpu=70%`;
`metricName` в триггерах KEDA устарел (2.10) и больше не нужен.

## PostgreSQL

| Задача | Запрос |
| :--- | :--- |
| Топ таблиц по размеру | `SELECT relname, pg_size_pretty(pg_total_relation_size(relid)) FROM pg_stat_user_tables ORDER BY pg_total_relation_size(relid) DESC LIMIT 10;` |
| Размер базы | `SELECT pg_size_pretty(pg_database_size('mydb'));` |

## Отчёт: обязательные поля

| Ресурс | Текущее | Тренд | Когда упрёмся | Действие, срок, владелец |
| :--- | :--- | :--- | :--- | :--- |
| CPU | 45% | +8%/мес | июль | +3 ноды к июню, @platform-team |
| Disk БД | 2 TB | +500 GB/мес | апрель | resize до 4 TB к марту, @dba |

> Проверка: арифметика пересчитана в python3; PromQL прошёл
> `promtool check rules` (prom/prometheus:v3.5.0); пороги k6 проверены
> `k6 run` (grafana/k6 v2.3.0); kubectl — `--help` v1.34.1; не
> проверено: KEDA ScaledObject (нет CRD локально), SQL (нет psql).
