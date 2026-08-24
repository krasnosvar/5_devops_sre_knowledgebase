# Раздел 8. SRE

Site Reliability Engineering: как обеспечить надёжность системы в продакшне
без того, чтобы превратить on-call в круглосуточный кошмар.

## Подразделы

1. [01_slo_sli_sla](./01_slo_sli_sla/) — SLI (что измеряем), SLO (цель),
   SLA (договор); error budget: откуда берётся и как тратится; почему 99.9% ≠ 99.99%
   в переводе на downtime; как выбирать правильные SLI для разных типов сервисов
   (request-based, pipeline, storage).

2. [02_error_budget_policy](./02_error_budget_policy/) — error budget policy:
   что делать, когда бюджет исчерпан (freeze features, reliability sprint); как
   вовлечь разработку в ответственность за надёжность без конфликта; burn rate
   алерты (быстрый и медленный ожог бюджета).

3. [03_incident_management](./03_incident_management/) — lifecycle инцидента:
   обнаружение → response → mitigation → resolution → postmortem; severity levels
   и как их определять; IC (Incident Commander) роль; communication во время
   инцидента (статус-пейджи, Slack каналы); чего не делать под давлением.

4. [04_postmortem](./04_postmortem/) — blameless postmortem: шаблон, 5 почему,
   как находить системные причины а не виновных; follow-up items и как не дать
   им потеряться; культура, при которой команда не боится признавать ошибки.

5. [05_on_call](./05_on_call/) — здоровый on-call: ротация, первичный и вторичный
   дежурный; runbook как артефакт; что делать с повторяющимися алертами
   (toil elimination); компенсация и предотвращение выгорания.

6. [06_chaos_engineering](./06_chaos_engineering/) — chaos engineering: принципы
   (гипотеза → эксперимент → blast radius → наблюдение); инструменты (Chaos Monkey,
   LitmusChaos для k8s, Gremlin); как начать без страха — gameday на staging.

7. [07_capacity_planning](./07_capacity_planning/) — планирование ёмкости:
   Little's Law, queueing theory основы, forecasting нагрузки; горизонтальное
   масштабирование и его пределы; load testing как инструмент (k6, Locust).

## Как проходить

01 → 02 → 03 → 04 — ядро SRE-практик, читать последовательно.
05 — перед первым on-call дежурством. 06 и 07 — по мере зрелости команды.

## Упражнения — тиры

🐳 Tier 1: написать SLO для demo-приложения, настроить burn rate alert в Prometheus
🖥 Tier 2: LitmusChaos в kind кластере
