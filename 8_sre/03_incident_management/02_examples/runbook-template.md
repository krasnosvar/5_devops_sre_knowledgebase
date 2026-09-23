# Runbook: [AlertName]

**Алерт:** `[AlertName]`  
**Сервис:** [service-name]  
**On-call:** @[team-name]  
**Создан:** [date] | **Обновлён:** [date]

---

## Что это означает

[1-2 предложения: что означает этот алерт, почему он важен]

---

## Влияние на пользователей

- **Затронутые функции:** [список]
- **Масштаб при SEV-2:** ~X% пользователей
- **Workaround для пользователей:** [есть/нет, описание]

---

## Диагностика (выполнять по порядку)

### Шаг 1 — Дашборд

Открыть: [ссылка на Grafana dashboard]

Смотреть:
- [ ] Error rate выше нормы?
- [ ] Latency выросла?
- [ ] Трафик аномальный?

### Шаг 2 — Логи

```bash
# Логи сервиса за последние 15 минут
kubectl logs -l app=[service] -n [namespace] --since=15m | grep -i error | tail -50

# или через logcli (Loki)
logcli query '{app="[service]"} |= "error"' --since=15m
```

### Шаг 3 — Зависимости

```bash
# Проверить что БД доступна
kubectl exec -it [db-pod] -n [namespace] -- pg_isready

# Проверить что cache доступен
kubectl exec -it [app-pod] -n [namespace] -- redis-cli -h [redis-host] ping

# Статус внешних сервисов
curl -sf https://status.stripe.com/api/v2/status.json | jq '.status.description'
```

### Шаг 4 — Последние изменения

```bash
kubectl rollout history deployment/[service] -n [namespace]
```

---

## Митигация

### Если проблема после деплоя

```bash
kubectl rollout undo deployment/[service] -n [namespace]
kubectl rollout status deployment/[service] -n [namespace]
```

### Если перегрузка

```bash
kubectl scale deployment/[service] --replicas=10 -n [namespace]
```

### Если проблема в конкретной фиче

```bash
# Выключить feature flag
kubectl set env deployment/[service] FEATURE_X_ENABLED=false -n [namespace]
```

---

## Эскалация

| Время без решения | Кому |
| --- | --- |
| > 15 мин | @[tech-lead] |
| > 30 мин или потеря данных | @[vp-engineering] |
| SEV-1 | @[incident-commander] немедленно |

---

## Постмортем требуется если

- Downtime > 15 минут
- > 5% пользователей затронуто
- Потеря данных (любой объём)
