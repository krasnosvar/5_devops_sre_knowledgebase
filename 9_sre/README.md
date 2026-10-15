# Раздел 9. SRE

Site Reliability Engineering: как обеспечить надёжность системы в продакшне
без того, чтобы превратить on-call в круглосуточный кошмар.

## Пререквизиты

- [8_observability](../8_observability/) — метрики (Prometheus, PromQL),
  алертинг и Grafana: на них строятся SLO и burn rate алерты.
- [4_kubernetes](../4_kubernetes/) — для chaos engineering (LitmusChaos в
  kind, 🖥 Tier 2) и примеров диагностики в runbook.

## Подразделы

1. [01_slo_sli_sla](./01_slo_sli_sla/) — SLI (что измеряем), SLO (цель), SLA
   (договор); error budget: откуда берётся и как тратится; почему 99.9% ≠ 99.99%
   в переводе на downtime; как выбирать правильные SLI для разных типов сервисов
   (request-based, pipeline, storage).

2. [02_error_budget_policy](./02_error_budget_policy/) — error budget policy:
   что делать, когда бюджет исчерпан (freeze features, reliability sprint); как
   вовлечь разработку в ответственность за надёжность без конфликта; burn rate
   алерты (быстрый и медленный ожог бюджета).

3. [03_incident_management](./03_incident_management/) — lifecycle инцидента:
   обнаружение → response → mitigation → resolution → postmortem; severity
   levels и как их определять; IC (Incident Commander) роль; communication во
   время инцидента (статус-пейджи, Slack каналы); чего не делать под давлением.

4. [04_postmortem](./04_postmortem/) — blameless postmortem: шаблон, 5 почему,
   как находить системные причины а не виновных; follow-up items и как не дать
   им потеряться; культура, при которой команда не боится признавать ошибки.

5. [05_on_call](./05_on_call/) — здоровый on-call: ротация, первичный и
   вторичный дежурный; runbook как артефакт; что делать с повторяющимися
   алертами (toil elimination); компенсация и предотвращение выгорания.

6. [06_chaos_engineering](./06_chaos_engineering/) — chaos engineering: принципы
   (гипотеза → эксперимент → blast radius → наблюдение); инструменты (Chaos
   Monkey, LitmusChaos для k8s, Gremlin); как начать без страха — gameday на
   staging.

7. [07_capacity_planning](./07_capacity_planning/) — планирование ёмкости:
   Little's Law, queueing theory основы, forecasting нагрузки; горизонтальное
   масштабирование и его пределы; load testing как инструмент (k6, Locust).

## Как проходить

01 → 02 → 03 → 04 — ядро SRE-практик, читать последовательно.
05 — перед первым on-call дежурством. 06 и 07 — по мере зрелости команды.

## Упражнения — тиры

🐳 Tier 1: написать SLO для demo-приложения, настроить burn rate alert в
Prometheus
🖥 Tier 2: LitmusChaos в kind кластере

## Сквозной практический пример

[README_practical.md](./README_practical.md) — полный цикл на одном сервисе: SLO
→ recording rules → burn rate алерты → дашборд → симуляция инцидента → подсчёт
потраченного бюджета → postmortem. Проходить после 01-04, на стенде
[8_observability/02_metrics_prometheus](../8_observability/02_metrics_prometheus/02_examples/).

## Когда двигаться дальше

- Можете для сервиса сформулировать SLI/SLO и посчитать error budget в
  минутах.
- Можете настроить burn rate алерт и объяснить его пороги.
- Можете провести инцидент по ролям и написать blameless postmortem с
  проверяемыми action items.

Дальше — [10_devsecops](../10_devsecops/).
