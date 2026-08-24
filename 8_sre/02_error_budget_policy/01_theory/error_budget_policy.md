# Error Budget Policy

## Что такое error budget policy

Договор внутри команды: что делать когда error budget исчерпывается.
Без политики SLO существует только на бумаге — никто не знает что делать при нарушении.

## Типичная политика

```
Error Budget Policy для [Сервис: Payment API]
SLO: 99.9% успешных запросов за 30 дней

──────────────────────────────────────────────────────
Остаток бюджета    Действие
──────────────────────────────────────────────────────
> 50%              Нормальный режим. Feature работа продолжается.

25–50%             Внимание. Команда проводит weekly review
                   надёжности. Анализ трендов.

< 25%              Reliability sprint начинается. Новые features
                   заморожены. Только баги и reliability задачи.

0% (исчерпан)      Feature freeze до конца периода (30 дней).
                   Только reliability работы + hotfixes.
                   Постмортем обязателен.

──────────────────────────────────────────────────────
Исключения:
  - Критические security fixes — всегда разрешены
  - A/B тест с <1% трафика — разрешён с approval tech lead
```

## Кто принимает решения

```
Error budget < 25%:
  → engineering manager + tech lead принимают решение о заморозке

Error budget = 0%:
  → product manager должен согласиться на feature freeze
  → VP Engineering уведомлён

Disagreement:
  → эскалация: VP Engineering принимает финальное решение
```

## Почему это важно для Product

Без error budget policy разработчики и продуктовые менеджеры спорят:
- PM: "Нам нужна эта фича к дедлайну"
- SRE: "Надёжность деградирует"

С политикой — правило известно заранее. Нет личного конфликта.
«Мы не можем деплоить новые фичи — не потому что я так хочу, а потому что мы исчерпали бюджет».

## Prometheus алерт на burn rate

```yaml
# Алерты для мониторинга состояния бюджета
groups:
  - name: error_budget
    rules:
      # 75% потрачено (25% осталось)
      - alert: ErrorBudget75PercentConsumed
        expr: |
          (1 - (
            1 - rate(http_requests_total{status=~"5.."}[30d])
                / rate(http_requests_total[30d])
          ) / (1 - 0.999)) < 0.25
        labels:
          severity: warning
        annotations:
          summary: "Error budget < 25% for {{ $labels.service }}"
          action: "Start reliability sprint, freeze new features"

      # Полностью исчерпан
      - alert: ErrorBudgetExhausted
        expr: |
          (1 - (
            1 - rate(http_requests_total{status=~"5.."}[30d])
                / rate(http_requests_total[30d])
          ) / (1 - 0.999)) <= 0
        labels:
          severity: critical
        annotations:
          summary: "Error budget EXHAUSTED for {{ $labels.service }}"
          action: "Feature freeze. Postmortem required. Escalate to VP Eng."
```

## Шаблон Dashboard для error budget

Grafana панели которые должны быть:
1. Текущий % оставшегося бюджета (gauge)
2. Burn rate за последний час / 6 часов / 24 часа (time series)
3. Trend: если продолжать с текущей скоростью — когда кончится? (annotation)
4. История инцидентов за период (event markers)
5. Action items из постмортемов (text panel)
