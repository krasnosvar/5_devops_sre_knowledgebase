# Упражнения — SLO / SLI / SLA

Стенд: 🐳 Tier 1 — Prometheus + Grafana из
[8_observability/02_metrics_prometheus/02_examples/](../../../8_observability/02_metrics_prometheus/02_examples/).

Источник метрики `http_requests_total{status=...}` — демо-сервер
[app.py](../../../8_observability/02_metrics_prometheus/04_exercises_answers/app.py)
из упражнения 04 по Prometheus (job `myapp` в `scrape_configs`). Трафик и ошибки
генерируются так:

```bash
python app.py &
# ~2% ошибок: 49 успешных запросов на 1 ошибочный, в цикле
while true; do
  for i in $(seq 49); do curl -s -o /dev/null localhost:8001/; done
  curl -s -o /dev/null localhost:8001/error
done
```

## 01 — Определить SLI и SLO

**Задача:** Для каждого сервиса ниже определить подходящий SLI и реалистичный
SLO.

```
Сервис 1: API для мобильного приложения (POST /orders)
  SLI: ?
  SLO: ?

Сервис 2: Batch job обработки платежей (запускается ночью)
  SLI: ?
  SLO: ?

Сервис 3: S3-совместимое хранилище файлов
  SLI: ?
  SLO: ?

Сервис 4: Realtime WebSocket уведомления
  SLI: ?
  SLO: ?
```

## 02 — PromQL для SLO

**Задача:** Написать PromQL запросы для SLO 99.9% (availability):

```promql
# 1. Текущий error rate за 30 дней
# TODO

# 2. Остаток error budget в % (0 = исчерпан, 1 = полный)
# TODO

# 3. Burn rate за последний час
# TODO: rate за 1 час / (1 - SLO)

# 4. Если текущий burn rate продолжится — когда закончится бюджет?
# Подсказка: 30d / burn_rate
```

## 03 — SLO Dashboard в Grafana

**Задача:** Создать дашборд с панелями:
1. Gauge: остаток error budget (0-100%)
2. Time series: burn rate за последние 7 дней
3. Stat: MTTR за последние 30 дней
4. Table: последние 5 инцидентов с продолжительностью

Панели 3-4 требуют данных об инцидентах, которых в Prometheus нет: их
источник — система управления инцидентами (через её API/datasource).
В лабе вместо них достаточно показать текущие SLO-алерты из метрики
`ALERTS` и объяснить, откуда в реальной системе брались бы MTTR и
список инцидентов.

## 04 — Burn rate alerts

**Задача:** Настроить два алерта:
1. Быстрый: burn rate > 14.4x за 1 час (critical)
2. Медленный: burn rate > 6x за 6 часов (warning)

Проверить, что алерты срабатывают через Alertmanager (при ~2% ошибок
из генератора выше быстрый алерт должен перейти в firing).
