# 01. SLO, SLI, SLA

## Зачем
«Сервис должен работать всегда» — не цель, а источник бесконечных
споров между разработкой и эксплуатацией. SLI/SLO переводят надёжность
в измеримые числа, а error budget говорит, сколько ненадёжности можно
«потратить» на релизы и эксперименты. На этом построены алерты по burn
rate и вся остальная SRE-практика.

## Пререквизиты
- [8_observability/01_observability_theory](../../8_observability/01_observability_theory/)
  — определения SLI/SLO/SLA, RED-метрики.
- [8_observability/02_metrics_prometheus](../../8_observability/02_metrics_prometheus/)
  — PromQL, alerting rules; стенд и демо-сервер `app.py` оттуда же
  используются в упражнениях.

## Файлы
- [01_theory/slo_sli_sla.md](./01_theory/slo_sli_sla.md) — определения,
  выбор SLI, что значат «девятки» в минутах простоя, error budget,
  PromQL для SLO, burn rate, типичные ошибки.
- [02_examples/slo-rules.yaml](./02_examples/slo-rules.yaml) —
  recording и alerting rules для SLO 99.9% (проверены
  `promtool check rules`).
- [03_exercises/README.md](./03_exercises/README.md) — 4 упражнения
  (выбор SLI/SLO, PromQL для SLO, дашборд, burn rate алерты), 🐳 Tier 1.
- [04_exercises_answers/](./04_exercises_answers/) — ответы
  `slo-answers.md` и готовый `slo-alerts.yml`.

## Как проходить
1. Прочитать теорию; руками пересчитать 99.9% и 99.99% в минуты
   простоя за месяц.
2. Разобрать `slo-rules.yaml`.
3. Поднять стенд Prometheus, запустить `app.py` и генератор ошибок
   (инструкция — в упражнениях), сделать упражнения.
4. Сверить с ответами.

## Когда двигаться дальше
- Можете для любого сервиса предложить SLI, который отражает опыт
  пользователя, а не загрузку CPU.
- Можете без подсказки посчитать burn rate и время до исчерпания
  бюджета.
- Можете объяснить, откуда берутся пороги 14.4x за 1 час и 6x за 6 часов.

Дальше — [02_error_budget_policy](../02_error_budget_policy/).
