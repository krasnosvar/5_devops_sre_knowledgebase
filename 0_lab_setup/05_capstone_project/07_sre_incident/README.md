# Шаг 7 — SRE: SLO, game day и постмортем

🐳 Tier 1 (стенд из шага 6). Теория — [9_sre](../../../9_sre/):
[01_slo_sli_sla](../../../9_sre/01_slo_sli_sla/),
[02_error_budget_policy](../../../9_sre/02_error_budget_policy/),
[03_incident_management](../../../9_sre/03_incident_management/),
[04_postmortem](../../../9_sre/04_postmortem/),
[06_chaos_engineering](../../../9_sre/06_chaos_engineering/).

Шаг 6 дал метрики и алерты. Теперь вопрос другой: насколько сервис
надёжен с точки зрения пользователя и что делать, когда он ломается.
Работаем на стенде из [../06_observability](../06_observability/).

## Задание

1. **SLO.** Описать для shortener 1–2 SLI (что считаем «хорошим»
   запросом) и SLO на 30 дней. Посчитать error budget в процентах и в
   минутах простоя.
2. **Game day.** Поднять стенд шага 6 с правилами из его ответа, дать
   постоянную нагрузку (`POST /shorten` в цикле), остановить Redis на
   5 минут. Вести таймлайн: когда начался сбой, когда сработал алерт,
   когда сервис восстановлен. Что видел пользователь, а что — метрики?
3. **Постмортем.** Написать blameless postmortem по шаблону
   [9_sre/04_postmortem](../../../9_sre/04_postmortem/02_examples/postmortem-template.md):
   влияние, таймлайн, корневая причина, что сработало/не сработало,
   action items с владельцем.
4. **Action item.** Устранить найденную в шаге 6 слепую зону — 5xx не
   попадают в метрики. Добавить метрику ответов по HTTP-коду и записать
   SLI и burn-rate алерты на ней.

Решение — [ANSWERS.md](ANSWERS.md) и
[answers/slo-rules.yaml](answers/slo-rules.yaml).
