# 06.2. Движки политик: OPA Gatekeeper и Kyverno

## Зачем
PSA проверяет только безопасность пода. Правила вида "никаких
`:latest`", "у каждого Deployment есть label `team`", "дефолтные
limits, если их забыли" ставятся admission-вебхуками — Gatekeeper или
Kyverno. Важно не только написать политику, но и понимать, что будет
с кластером, когда сам движок упадёт.

## Пререквизиты
- [01_core](../01_core/) — PSA и SecurityContext.
- [01_architecture](../../01_architecture/) — §4, фазы admission.

> **Забегание вперёд.** Здесь используется Helm, который подробно
> разбирается в [07_manifests_management](../../07_manifests_management/).
> Для этой темы достаточно: `helm repo add`, `helm install`,
> `helm uninstall`. Если Helm ещё не освоен — просто выполняйте команды
> из упражнений как есть.

## Файлы
- [01_theory/policy_engines.md](./01_theory/policy_engines.md) —
  Gatekeeper (Rego, ConstraintTemplate + Constraint), Kyverno (YAML,
  validate/mutate, актуальный синтаксис), failurePolicy.
- [02_examples/](./02_examples/) — `kyverno-policy.yaml` (запрет
  `:latest` и дефолтные limits), `opa-constraint.yaml` (то же правило
  на Rego).
- [03_exercises/README.md](./03_exercises/README.md) — 4 упражнения,
  🐳 Tier 1 (kind).
- [04_exercises_answers/](./04_exercises_answers/) —
  [policy-engines-answers.md](./04_exercises_answers/policy-engines-answers.md)
  и `kyverno-policy-ignore.yaml`.

## Как проходить
1. Теория.
2. Упражнения 01-02 (Kyverno), 03 (Gatekeeper, предварительно убрав
   политики Kyverno), 04 (failurePolicy на Kyverno).
3. Сверка с ответами.

## Когда двигаться дальше
- Можете объяснить разницу ConstraintTemplate и Constraint.
- Можете написать validate- и mutate-политику Kyverno в актуальном
  синтаксисе (`validate.failureAction`, `match.any`).
- Можете объяснить, почему `failurePolicy` выбирают заранее, а не во
  время аварии.

Дальше — [07_manifests_management](../../07_manifests_management/).
