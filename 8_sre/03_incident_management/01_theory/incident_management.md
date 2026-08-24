# Incident Management

## Lifecycle инцидента

```
Detection → Triage → Response → Mitigation → Resolution → Postmortem
```

**Detection** — как обнаружили: алерт, жалоба пользователя, собственное обнаружение.
Время от возникновения до обнаружения = detection latency.

**Triage** — оценка severity. Быстро: что сломано, кто затронут, насколько критично.

**Response** — сформировать команду, открыть incident channel, назначить IC.

**Mitigation** — убрать симптом (не обязательно root cause): откатить деплой,
отключить фичу, переключить трафик. Цель: восстановить сервис.

**Resolution** — устранить root cause. Может занять дни после mitigation.

**Postmortem** — разбор: что произошло, почему, что делаем чтобы не повторилось.

## Severity levels

```
SEV-1 / P0 — Критический
  - Production полностью недоступен
  - Потеря данных пользователей
  - Финансовые транзакции заблокированы
  - Реакция: немедленно, все доступные инженеры

SEV-2 / P1 — Высокий
  - Ключевой функционал недоступен для части пользователей
  - Деградация производительности > 50%
  - Реакция: в течение 15 минут

SEV-3 / P2 — Средний
  - Минорный функционал недоступен
  - Есть workaround для пользователей
  - Реакция: в рабочее время

SEV-4 / P3 — Низкий
  - Косметические проблемы
  - Влияет на <1% пользователей
  - Реакция: в плановом порядке
```

## Роли в инциденте

**IC (Incident Commander)** — координирует, не делает технические решения сам.
Следит за процессом, распределяет задачи, общается со стейкхолдерами.

**Tech Lead** — принимает технические решения (откатить/масштабировать/исправить).

**Comms Lead** — пишет статус-апдейты, общается с customers/support.

**Scribe** — записывает timeline: что сделали, что обнаружили, когда.

*В маленьких командах один человек может совмещать несколько ролей.*

## Communication во время инцидента

```
1. Создать incident channel: #incident-2024-01-15-payment-down
2. Первый апдейт (через 5 мин после detection):
   "SEV-2. Payment service returning 503. Investigation started.
    Affected: checkout flow. Next update in 15 min."

3. Регулярные апдейты каждые 15-30 мин:
   "Update: identified memory leak in payments-v2.3.1.
    Rolling back to v2.3.0. ETA recovery: 10 min."

4. Resolution:
   "RESOLVED 14:35 UTC. Root cause: memory leak in payments-v2.3.1.
    Mitigation: rollback to v2.3.0. Recovery time: 47 min.
    Postmortem scheduled for tomorrow 10:00 UTC."
```

**Статус-страница** — публичная коммуникация с пользователями.
Обновлять честно и своевременно лучше чем молчать.

## Runbook — инструкция к алерту

```markdown
# Alert: PaymentServiceHighErrorRate

## Что это означает
Доля ошибок payment-service превысила 5% за последние 5 минут.

## Влияние на пользователей
Часть платёжных транзакций завершается с ошибкой.

## Диагностика (шаги по порядку)

1. Проверить метрики:
   - Grafana: https://grafana.example.com/d/payments
   - Ключевые: error_rate, latency p95, active_requests

2. Проверить логи:
   ```
   kubectl logs -n payments -l app=payment-service --tail=100 | grep ERROR
   ```

3. Проверить зависимости:
   - БД: `kubectl exec -n payments db-0 -- psql -c "SELECT count(*) FROM pg_stat_activity WHERE state='active'"`
   - Redis: `redis-cli -h redis.payments ping`
   - Внешние API: https://status.stripe.com/

4. Проверить последние деплои:
   ```
   kubectl rollout history deployment/payment-service -n payments
   ```

## Митигация

Если проблема после деплоя:
```
kubectl rollout undo deployment/payment-service -n payments
```

Если перегрузка:
```
kubectl scale deployment/payment-service --replicas=10 -n payments
```

## Эскалация
- Если не решено за 15 мин: @payments-team-lead
- Если потеря данных: немедленно @cto @head-of-engineering
```

## Что не делать под давлением

- **Не паниковать** — медленное и правильное лучше быстрого и случайного
- **Не вносить несколько изменений одновременно** — не поймёшь что помогло
- **Не игнорировать коммуникацию** — молчание хуже плохих новостей
- **Не пропускать постмортем** — повторишься
- **Не искать виноватого** — ищи системные причины
