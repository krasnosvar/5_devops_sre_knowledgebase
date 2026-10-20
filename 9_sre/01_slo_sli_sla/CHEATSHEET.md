# SLO, SLI, SLA — шпаргалка

Подробности и объяснения — в
[slo_sli_sla.md](./01_theory/slo_sli_sla.md). ⚠️ — частая ловушка.

## Термины

| Термин | Что это | Пример |
| :--- | :--- | :--- |
| SLI | измеряемая метрика опыта пользователя | доля успешных запросов за 30 дней |
| SLO | внутренняя цель для SLI | SLI >= 99.9% |
| SLA | договор с клиентом, штрафы при нарушении | SLI >= 99.5% (мягче SLO — запас) |
| Error budget | `1 - SLO` | 0.1% запросов или 43.2 мин за 30 дней |
| Burn rate | `error_ratio / (1 - SLO)` | 1 = бюджет кончится ровно к концу окна |

## Девятки → простой

Окно 30 дней / 7 дней / 365 дней.

| SLO | Бюджет | За 30 дней | За неделю | За год |
| :--- | :--- | :--- | :--- | :--- |
| 99% | 1% | 7.2 ч | 1.68 ч | 3.65 дня |
| 99.5% | 0.5% | 3.6 ч | 50.4 мин | 1.83 дня |
| 99.9% | 0.1% | 43.2 мин | 10.1 мин | 8.76 ч |
| 99.95% | 0.05% | 21.6 мин | 5.04 мин | 4.38 ч |
| 99.99% | 0.01% | 4.32 мин | 1.01 мин | 52.6 мин |
| 99.999% | 0.001% | 25.9 с | 6 с | 5.26 мин |

## Какой SLI выбрать

| Тип сервиса | SLI | Хорошие события / все |
| :--- | :--- | :--- |
| API, web | Availability | не-5xx / все запросы |
| API, web | Latency | запросы быстрее порога (например, < 300ms) / все |
| API, web | Quality | ответы с корректными данными / все |
| Pipeline, batch | Freshness | lag от источника < N минут |
| Pipeline, batch | Completeness | обработанные записи / поступившие |
| Pipeline, batch | Throughput | записей/сек |
| Хранилище | Durability, availability | успешные read/write / все |

## PromQL

| Задача | Запрос |
| :--- | :--- |
| Error ratio за 5 минут | `sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))` |
| SLI availability за 30 дней, % | `(1 - sum(increase(http_requests_total{status=~"5.."}[30d])) / sum(increase(http_requests_total[30d]))) * 100` |
| Latency SLI: доля быстрее 300ms | `sum(rate(http_request_duration_seconds_bucket{le="0.3"}[5m])) / sum(rate(http_request_duration_seconds_count[5m]))` |
| Остаток бюджета (1 — полон, 0 — исчерпан) | `1 - (sum(rate(http_requests_total{status=~"5.."}[30d])) / sum(rate(http_requests_total[30d]))) / 0.001` |
| Burn rate за 1 час | `(sum(rate(http_requests_total{status=~"5.."}[1h])) / sum(rate(http_requests_total[1h]))) / 0.001` |

⚠️ `0.001` — это `1 - SLO` для 99.9%; при другом SLO меняйте.
⚠️ Latency SLI требует bucket `le` ровно на пороге — иначе выберите
ближайший существующий.

## Multiwindow multi-burn-rate (SLO 99.9%, окно 30 дней)

`burn = доля_бюджета × 720 ч / длинное_окно`; время до исчерпания
`= 30 дней / burn`.

| Длинное / короткое окно | Burn rate | Сжигает бюджета | Порог error ratio | Бюджет кончится за | Реакция |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 1h / 5m | 14.4 | 2% за 1 ч | 1.44% | 50 ч (~2 дня) | page |
| 6h / 30m | 6 | 5% за 6 ч | 0.6% | 5 дней | page |
| 1d / 2h | 3 | 10% за 24 ч | 0.3% | 10 дней | ticket |
| 3d / 6h | 1 | 10% за 3 дня | 0.1% | 30 дней | ticket |

Короткое окно (1/12 длинного) нужно, чтобы алерт быстро погас после
починки.

```yaml
groups:
  - name: slo-burn
    rules:
      - record: job:sli_error_ratio:rate5m
        expr: |
          sum by (job) (rate(http_requests_total{status=~"5.."}[5m]))
          / sum by (job) (rate(http_requests_total[5m]))
      - record: job:sli_error_ratio:rate1h
        expr: |
          sum by (job) (rate(http_requests_total{status=~"5.."}[1h]))
          / sum by (job) (rate(http_requests_total[1h]))
      - alert: SLOBurnRateFast
        expr: |
          job:sli_error_ratio:rate1h > (14.4 * 0.001)
          and job:sli_error_ratio:rate5m > (14.4 * 0.001)
        for: 2m
        labels:
          severity: page
```

| Задача | Команда |
| :--- | :--- |
| Проверить синтаксис правил | `promtool check rules slo-rules.yaml` |
| Юнит-тест алерта на синтетических сериях | `promtool test rules slo-test.yaml` |

## Ловушки

| Ошибка | Чем плохо | Как правильно |
| :--- | :--- | :--- |
| ⚠️ Слишком высокий SLO на старте | бюджет всегда пуст, команда выгорает | начать с 99.5%, повышать |
| ⚠️ SLI «сервер вернул 200» | не отражает опыт пользователя | мерить корректность ответа |
| ⚠️ Мерить изнутри сервиса | не видно сбоев LB/сети | мерить на ingress/LB или у клиента |
| ⚠️ Нет error budget policy | SLO ни на что не влияет | договориться о действиях заранее |
| ⚠️ Алерт только по 30d-окну | реакция через дни | burn rate по 1h/6h окнам |
| ⚠️ SLA = SLO | нет запаса до штрафов | SLA мягче внутреннего SLO |

> Проверка: таблицы девяток и burn rate пересчитаны в python3; блок
> правил прошёл `promtool check rules` и `promtool test rules`
> (prom/prometheus:v3.5.0); не проверено: —.
