# 03. Incident Management

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — команды и шаблоны одним экраном.

## Зачем
Инцидент случится обязательно; вопрос — сколько он продлится и
сколько хаоса создаст. Чёткий lifecycle, уровни severity, роли
(Incident Commander) и правила коммуникации сокращают время
восстановления сильнее, чем любой отдельный инструмент.

## Пререквизиты
- [01_slo_sli_sla](../01_slo_sli_sla/) и
  [02_error_budget_policy](../02_error_budget_policy/) — как
  определяется «это инцидент» и его цена.
- [8_observability/07_alerting](../../8_observability/07_alerting/) —
  откуда приходит сигнал.
- [4_kubernetes/13_troubleshooting](../../4_kubernetes/13_troubleshooting/)
  — команды диагностики, на которые ссылаются примеры runbook.

## Файлы
- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: severity, роли, коммуникация, команды.
- [01_theory/incident_management.md](./01_theory/incident_management.md)
  — lifecycle инцидента, severity, роли, коммуникация, runbook к
  алерту, чего не делать под давлением.
- [02_examples/runbook-template.md](./02_examples/runbook-template.md) —
  шаблон runbook для алерта.

Без лабы: тема о процессе. Сквозная симуляция инцидента — в
[README_practical.md](../README_practical.md) (шаги 5-6).

## Как проходить
1. Прочитать теорию.
2. Написать по шаблону runbook для одного из алертов, созданных в
   [упражнениях по Prometheus](../../8_observability/02_metrics_prometheus/03_exercises/README.md).
3. Пройти шаги 5-6 сквозного примера.

## Когда двигаться дальше
- Можете назвать роли в инциденте и чем занят Incident Commander
  (подсказка: не чинит сам).
- Можете определить severity по влиянию на пользователей.
- Можете написать первое сообщение о статусе инцидента за минуту.

Дальше — [04_postmortem](../04_postmortem/).
