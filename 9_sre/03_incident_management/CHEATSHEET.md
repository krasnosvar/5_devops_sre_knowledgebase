# Incident Management — шпаргалка

Подробности и объяснения — в
[incident_management.md](./01_theory/incident_management.md). ⚠️ —
опасная команда или частая ловушка.

## Lifecycle

| Фаза | Цель | Результат |
| :--- | :--- | :--- |
| Detection | узнать о проблеме (алерт, жалоба) | время до обнаружения — detection latency |
| Triage | что сломано, кто затронут, severity | SEV-уровень |
| Response | собрать людей | incident channel, назначен IC |
| Mitigation | убрать симптом (rollback, feature off, трафик) | сервис восстановлен |
| Resolution | устранить root cause | фикс, может занять дни |
| Postmortem | системные причины, action items | документ + тикеты |

## Severity

| Уровень | Признаки | Реакция |
| :--- | :--- | :--- |
| SEV-1 / P0 | prod недоступен, потеря данных, платежи стоят | немедленно, все доступные |
| SEV-2 / P1 | ключевая функция недоступна части пользователей, деградация > 50% | в течение 15 мин |
| SEV-3 / P2 | минорная функция, есть workaround | в рабочее время |
| SEV-4 / P3 | косметика, < 1% пользователей | в плановом порядке |

## Роли

| Роль | Делает | Не делает |
| :--- | :--- | :--- |
| Incident Commander (IC) | координирует, раздаёт задачи, говорит со стейкхолдерами | не чинит руками |
| Tech Lead | технические решения: rollback / scale / fix | не пишет апдейты |
| Comms Lead | статус-апдейты, support, status page | — |
| Scribe | timeline: что сделали, что увидели, когда | — |

В маленькой команде роли совмещаются, но IC и «чинящий» — по
возможности разные люди.

## Коммуникация

| Когда | Что | Пример |
| :--- | :--- | :--- |
| Старт | канал `#incident-YYYY-MM-DD-<кратко>` | `#incident-2024-01-15-payment-down` |
| ~5 мин после detection | первый апдейт: SEV, симптом, затронуто, след. апдейт | `SEV-2. Payment 503. Affected: checkout. Next update in 15 min.` |
| Каждые 15–30 мин | что нашли, что делаем, ETA | `Rolling back to v2.3.0. ETA 10 min.` |
| Resolved | время, причина, митигация, длительность, дата postmortem | `RESOLVED 14:35 UTC ... Postmortem tomorrow 10:00 UTC.` |

## Команды диагностики и митигации (Kubernetes)

| Задача | Команда |
| :--- | :--- |
| Ошибки в логах сервиса | `kubectl logs -n <ns> -l app=<app> --tail=100 \| grep ERROR` |
| Последние деплои | `kubectl rollout history deployment/<name> -n <ns>` |
| Статус раскатки | `kubectl rollout status deployment/<name> -n <ns>` |
| События namespace по времени | `kubectl get events -n <ns> --sort-by=.lastTimestamp` |
| Откатить деплой ⚠️ | `kubectl rollout undo deployment/<name> -n <ns>` |
| Откатить на конкретную ревизию ⚠️ | `kubectl rollout undo deployment/<name> -n <ns> --to-revision=<N>` |
| Масштабировать при перегрузке | `kubectl scale deployment/<name> --replicas=10 -n <ns>` |
| Активные сессии PostgreSQL | `psql -c "SELECT count(*) FROM pg_stat_activity WHERE state='active'"` |
| Жив ли Redis | `redis-cli -h <host> ping` |

## Runbook — скелет

```markdown
# Alert: <AlertName>
## Что это означает      — условие алерта простыми словами
## Влияние на пользователей
## Диагностика           — шаги по порядку: дашборд, логи, зависимости, деплои
## Митигация             — rollback / scale / feature off, готовые команды
## Эскалация             — кому и через сколько минут
```

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| Ошибки начались сразу после релиза | `kubectl rollout history`, diff версий → rollback |
| Растёт latency, ошибок нет | p95 в Grafana, зависимости (БД, внешние API, status page) |
| 5xx и исчерпан пул соединений | `pg_stat_activity`, число реплик × размер пула |
| Падает внешний провайдер | его status page, включить fallback |

## Ловушки

| Ошибка | Почему плохо |
| :--- | :--- |
| ⚠️ Несколько изменений одновременно | непонятно, что помогло |
| ⚠️ Искать root cause до mitigation | пользователи страдают дольше |
| ⚠️ Молчать в канале | стейкхолдеры дёргают инженеров напрямую |
| ⚠️ Искать виноватого | люди начинают скрывать ошибки |
| ⚠️ Пропустить postmortem | инцидент повторится |

> Проверка: команды kubectl сверены с `kubectl <cmd> --help`
> (v1.34.1, без кластера); не проверено: psql/redis-cli (нет
> локально, синтаксис стандартный).
