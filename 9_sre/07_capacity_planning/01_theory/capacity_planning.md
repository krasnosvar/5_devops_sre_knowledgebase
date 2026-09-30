# Capacity Planning

## Зачем нужно планирование ёмкости

Без планирования: система неожиданно ломается под нагрузкой или простаивает переплаченными ресурсами.

**Цели:**
- Предсказать когда текущей ёмкости перестанет хватать
- Закупить/заказать ресурсы до того как они понадобятся (не в панике)
- Не переплачивать за неиспользуемые ресурсы

## Little's Law

Фундаментальный закон очередей:

```
L = λ × W

L = среднее количество запросов в системе
λ = throughput (запросов/секунда)
W = среднее время нахождения в системе (latency)

Пример:
  λ = 100 req/s
  W = 50ms = 0.05s
  L = 100 × 0.05 = 5 запросов одновременно

Вывод: чтобы держать latency ≤ 50ms при 100 req/s,
система должна обрабатывать минимум 5 параллельных запросов.
```

## Методология

### 1. Измерить текущие ресурсы и их использование

```promql
# CPU utilization trend
avg by(instance)(1 - rate(node_cpu_seconds_total{mode="idle"}[1h]))

# Memory usage trend  
1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)

# Disk usage trend
1 - (node_filesystem_free_bytes / node_filesystem_size_bytes)

# Request rate trend
sum(rate(http_requests_total[1h]))
```

### 2. Построить trend (линейная регрессия)

```python
import numpy as np
from datetime import datetime, timedelta

# Данные использования CPU за последние 3 месяца (из Prometheus)
timestamps = [...]  # Unix timestamps
cpu_usage = [...]   # 0.0 - 1.0

# Линейная регрессия
x = np.array(timestamps)
y = np.array(cpu_usage)
coeffs = np.polyfit(x, y, 1)  # slope, intercept

# Предсказать когда достигнет 80%
threshold = 0.8
days_until_80 = (threshold - coeffs[1]) / coeffs[0] / 86400
print(f"CPU достигнет 80% через {days_until_80:.0f} дней")
```

### 3. Load Testing — найти предел системы

```bash
# k6 — нагрузочное тестирование
cat > load-test.js << 'EOF'
import http from 'k6/http';
import { check } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 100 },    // разогрев до 100 VU
    { duration: '5m', target: 100 },    // держать 100 VU
    { duration: '2m', target: 500 },    // резкий рост
    { duration: '5m', target: 500 },    // держать 500 VU
    { duration: '2m', target: 1000 },   // ещё рост
    { duration: '5m', target: 1000 },   // держать
    { duration: '2m', target: 0 },      // охлаждение
  ],
  thresholds: {
    http_req_duration: ['p95<500'],     // 95% < 500ms
    http_req_failed: ['rate<0.01'],     // < 1% ошибок
  },
};

export default function() {
  let res = http.get('http://api.example.com/api/v1/users');
  check(res, { 'status was 200': (r) => r.status === 200 });
}
EOF

k6 run load-test.js
# Смотреть: когда latency начинает расти, когда появляются ошибки
```

## Прогнозирование роста

```python
# Простая экстраполяция
def forecast_growth(current_load, growth_rate_monthly, months_ahead):
    """
    current_load: текущая нагрузка (RPS, пользователи и т.д.)
    growth_rate_monthly: ежемесячный рост в долях (0.1 = 10%)
    months_ahead: на сколько месяцев вперёд
    """
    return current_load * (1 + growth_rate_monthly) ** months_ahead

# Пример:
# Сейчас: 1000 RPS
# Рост: 15%/месяц (типично для растущего продукта)
# Через 6 месяцев:
forecast_growth(1000, 0.15, 6)  # ~2313 RPS

# Текущий предел системы (из load test): 1500 RPS
# Вывод: через ~3 месяца нужно масштабировать
```

## Правило большого пальца для k8s

```bash
# 1. Целевое использование CPU: 60-70% (оставить запас для пиков)
# 2. Целевое использование Memory: 70-80%
# 3. Держать N+2 ноды (при выходе 2 нод кластер работает)

# Горизонтальное масштабирование (предпочтительнее вертикального)
kubectl autoscale deployment myapp --cpu-percent=70 --min=3 --max=50

# KEDA — масштабирование по внешним метрикам (Kafka lag, очередь)
kubectl apply -f - <<EOF
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
        metricName: http_requests_total
        query: sum(rate(http_requests_total[2m]))
        threshold: "100"   # 100 RPS на реплику
EOF
```

## Capacity Planning для баз данных

```sql
-- PostgreSQL: сколько места растёт в день
SELECT
  relname AS table,
  pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
  pg_size_pretty(pg_relation_size(relid)) AS data_size
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 10;

-- Оценить рост: сравнить за 7 дней
-- (нужна метрика pg_database_size из node_exporter/postgres_exporter)
```

```promql
# Prometheus: рост базы данных
deriv(pg_database_size_bytes{datname="mydb"}[7d])
# в байтах/секунду

# Перевести в GB/день
deriv(pg_database_size_bytes{datname="mydb"}[7d]) * 86400 / 1024^3
```

## Actionable Output

Capacity planning должен заканчиваться конкретными действиями:

```markdown
## Capacity Planning Report — Q1 2024

### Выводы
- CPU: текущее использование 45%, рост 8%/мес → нужно масштабировать к июлю
- Memory: 60%, стабильно → OK на 12+ месяцев
- Disk (PostgreSQL): рост 500 GB/мес → нужен resize с 2TB до 4TB до апреля
- Network: 2 Gbps peak, лимит 10 Gbps → OK

### Action Items
| Действие | Дедлайн | Ответственный |
|----------|---------|---------------|
| Добавить 3 worker ноды (от 10 до 13) | Июнь 2024 | @platform-team |
| Resize RDS storage 2TB → 4TB | Март 2024 | @dba |
| Включить HPA для api-service | Апрель 2024 | @backend-team |
```
