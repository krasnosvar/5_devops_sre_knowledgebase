# Error Budget Policy Template

**Сервис:** _________________  
**SLO:** ____% за 30 дней  
**Error Budget:** _____ минут/месяц  
**Дата принятия:** _________________  
**Участники:** Engineering Manager, Tech Lead, Product Manager

---

## Текущий статус

| Остаток бюджета | Статус | Действие |
| --- | --- | --- |
| > 50% | 🟢 Нормальный | Feature работа продолжается без ограничений |
| 25–50% | 🟡 Внимание | Weekly reliability review. Анализ трендов. |
| 10–25% | 🟠 Reliability Sprint | Заморозить новые фичи. Только bug fix + reliability. |
| < 10% | 🔴 Feature Freeze | Заморозить всё кроме hotfixes. Ежедневный review. |
| 0% | 🚨 Исчерпан | Feature freeze до конца периода. Постмортем обязателен. |

---

## Исключения

Следующие работы разрешены даже при feature freeze:

- Critical security patches
- Compliance-required changes
- A/B тест с ≤ 1% трафика (требует approval Tech Lead)

---

## Процесс принятия решений

```
Бюджет < 25%:
    Engineering Manager + Tech Lead → решение о заморозке

Бюджет = 0%:
    Product Manager соглашается на feature freeze →
    Engineering Manager документирует →
    VP Engineering уведомлён

Разногласия:
    Эскалация к VP Engineering (финальное слово)
```

---

## Метрики policy

Каждый квартал измерять:

- Сколько раз бюджет опускался ниже 25%?
- MTTR по инцидентам этого сервиса
- Процент action items из постмортемов, закрытых в срок
