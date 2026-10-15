# 09.4. Argo Rollouts: прогрессивная доставка

## Зачем
Обычный Deployment раскатывает новую версию, пока поды проходят
readiness probe, даже если пользователи уже получают ошибки. Argo
Rollouts добавляет canary и blue/green с проверкой метрик на каждом
шаге и автоматическим откатом — так плохой релиз задевает 5% трафика,
а не всех.

## Пререквизиты
- [02_workloads](../../02_workloads/) — стратегия RollingUpdate и
  probes.
- [03_networking](../../03_networking/) — Service и Ingress: через них
  делится трафик.
- [01_theory общей темы](../01_theory/gitops.md) — Rollout обычно
  доставляется GitOps-агентом.

> **Забегание вперёд.** AnalysisTemplate в примере обращается к
> Prometheus, который подробно разбирается в
> [8_observability](../../../8_observability/). Для этой темы
> достаточно понимать, что PromQL-запрос возвращает число (здесь — долю
> 5xx-ответов), которое сравнивается с порогом.

## Файлы
- [01_theory/argo_rollouts.md](./01_theory/argo_rollouts.md) — зачем
  Rollout вместо Deployment, canary steps, AnalysisTemplate,
  blue/green.
- [02_examples/rollout-canary.yaml](./02_examples/rollout-canary.yaml)
  — Rollout с canary-шагами и фоновым анализом + AnalysisTemplate.

Без упражнений: осмысленная лаба требует контроллера Argo Rollouts,
ingress/mesh с разделением трафика и Prometheus с реальными
метриками приложения.

## Как проходить
1. Теория.
2. Разобрать пример: какой шаг сейчас идёт, когда стартует анализ, что
   будет при двух неудачных замерах.
3. Interview Q&A в конце теории.

## Когда двигаться дальше
- Можете объяснить разницу canary и blue/green по ресурсам и скорости
  отката.
- Знаете, что делает `pause: {}` без `duration` и как продолжить.
- Понимаете, чем AnalysisTemplate отличается от readiness probe.

Дальше — [10_pod_autoscaling](../../10_pod_autoscaling/).
