# 06.1. Безопасность: основа (RBAC, Pod Security, NetworkPolicy, секреты)

## Зачем
Это минимум, без которого нельзя выпускать манифесты в production:
кто и что может делать в API (RBAC), с какими правами работает
контейнер (SecurityContext, PSA), с кем под может общаться
(NetworkPolicy) и где хранятся пароли.

## Пререквизиты
- [01_architecture](../../01_architecture/) — authentication,
  authorization, admission.
- [03_networking](../../03_networking/) — §3 о NetworkPolicy.

## Файлы
- [01_theory/security.md](./01_theory/security.md) — RBAC,
  ServiceAccount и bound-токены, OIDC, SecurityContext и кратко PSA
  (подробно — в
  [10_devsecops/05_pod_security](../../../10_devsecops/05_pod_security/)),
  NetworkPolicy, ESO и SOPS, Falco, audit log.
- [02_examples/rbac-demo.yaml](./02_examples/rbac-demo.yaml) —
  namespace с PSA, ServiceAccount, Role/RoleBinding с `resourceNames`,
  под с жёстким securityContext.
- [03_exercises/README.md](./03_exercises/README.md) — 4 упражнения,
  🐳 Tier 1 (kind).
- [04_exercises_answers/](./04_exercises_answers/) —
  [rbac-answers.md](./04_exercises_answers/rbac-answers.md) (команды и
  вывод), `netpol-answer.yaml`, `pss-answer.yaml`, `rbac-answer.yaml`.

## Как проходить
1. Теория, затем `kubectl apply -f 02_examples/rbac-demo.yaml` и
   проверка прав через `kubectl auth can-i`.
2. Упражнения 01-04.
3. Сверка с `rbac-answers.md`.

## Когда двигаться дальше
- Можете объяснить, что даёт `RoleBinding` на `ClusterRole`.
- Можете без подсказки написать default deny с разрешением DNS.
- Знаете, почему `automountServiceAccountToken: false` стоит включать
  по умолчанию.

Дальше — [02_policy_engines](../02_policy_engines/).
