# Error Budget Policy — шпаргалка

Подробности и объяснения — в
[error_budget_policy.md](./01_theory/error_budget_policy.md). ⚠️ —
частая ловушка.

## Остаток бюджета → действие

Пример для SLO 99.9% за 30 дней.

| Остаток бюджета | Режим | Действие |
| :--- | :--- | :--- |
| > 50% | нормальный | фичи идут как обычно |
| 25–50% | внимание | weekly review надёжности, анализ трендов |
| < 25% | reliability sprint | новые фичи заморожены, только баги и надёжность |
| 0% | feature freeze | до конца окна только reliability и hotfix, postmortem обязателен |

| Исключение | Условие |
| :--- | :--- |
| Критический security fix | разрешён всегда |
| A/B-тест на < 1% трафика | с approval tech lead |

## Кто решает

| Ситуация | Решение | Уведомить |
| :--- | :--- | :--- |
| Бюджет < 25% | engineering manager + tech lead | — |
| Бюджет 0% | product manager соглашается на freeze | VP Engineering |
| Разногласие | эскалация, финальное решение — VP Engineering | — |

## Бюджет в числах

| Величина | Формула | SLO 99.9%, 30 дней |
| :--- | :--- | :--- |
| Бюджет по времени | `30 × 24 × 60 × (1 - SLO)` | 43.2 мин |
| Бюджет по запросам | `всего_запросов × (1 - SLO)` | 10 000 из 10 млн |
| Потрачено | `error_ratio_30d / (1 - SLO)` | 0.75 = потрачено 75% |
| Остаток | `1 - error_ratio_30d / (1 - SLO)` | 0.25 = осталось 25% |
| Когда кончится | `остаток × 30 дней / burn_rate` | 25% при burn 2 → 3.75 дня |

## Алерты на состояние бюджета

```yaml
groups:
  - name: error_budget
    rules:
      - alert: ErrorBudgetLow
        expr: |
          1 - (
            sum(rate(http_requests_total{status=~"5.."}[30d]))
            / sum(rate(http_requests_total[30d]))
          ) / (1 - 0.999) < 0.25
        labels:
          severity: warning
        annotations:
          summary: "Осталось < 25% error budget: reliability sprint"
      - alert: ErrorBudgetExhausted
        expr: |
          1 - (
            sum(rate(http_requests_total{status=~"5.."}[30d]))
            / sum(rate(http_requests_total[30d]))
          ) / (1 - 0.999) <= 0
        labels:
          severity: critical
        annotations:
          summary: "Error budget исчерпан: feature freeze, postmortem"
```

Быстрое сжигание (burn rate 14.4 / 6) — в
[шпаргалке SLO](../01_slo_sli_sla/CHEATSHEET.md#multiwindow-multi-burn-rate-slo-999-окно-30-дней).

## Дашборд бюджета в Grafana

| Панель | Тип |
| :--- | :--- |
| Остаток бюджета, % | gauge |
| Burn rate за 1 ч / 6 ч / 24 ч | time series |
| Прогноз: когда кончится при текущей скорости | stat / annotation |
| Инциденты за период | annotations (event markers) |
| Action items из постмортемов | text |

## Ловушки

| Ошибка | Последствие |
| :--- | :--- |
| ⚠️ Политика не согласована с product заранее | спор PM и SRE в момент кризиса |
| ⚠️ Freeze без исключений для security fix | уязвимость висит до конца окна |
| ⚠️ Алерт только на «бюджет исчерпан» | реагируют, когда поздно; нужны пороги 50/25% |
| ⚠️ `rate(...[30d])` по сырым сериям | тяжёлый запрос; выносите в recording rules |

> Проверка: формулы пересчитаны в python3, блок правил прошёл
> `promtool check rules` (prom/prometheus:v3.5.0); не проверено: —.
