# 06. Безопасность Kubernetes

## Зачем
Кластер по умолчанию открыт: любой под может ходить к любому, токен
ServiceAccount монтируется во все поды, контейнеры стартуют от root.
Тема даёт встроенные механизмы, которые это закрывают (RBAC,
SecurityContext, Pod Security Admission, NetworkPolicy, секреты,
аудит), и движки политик для правил, которых во встроенных механизмах
нет.

## Пререквизиты
- [01_architecture](../01_architecture/) — фазы обработки запроса в
  apiserver (authentication → authorization → admission).
- [03_networking](../03_networking/) — NetworkPolicy и CNI.
- [3_containers/05_security](../../3_containers/05_security/) —
  capabilities, seccomp, rootless.

## Файлы
Тема разбита на две подтемы, у каждой свои теория, примеры,
упражнения и ответы:
- [01_core/](./01_core/) — RBAC, ServiceAccount и токены, OIDC,
  SecurityContext и PSA, NetworkPolicy, секреты, Falco, аудит.
- [02_policy_engines/](./02_policy_engines/) — OPA Gatekeeper vs
  Kyverno, validate/mutate, failurePolicy.

Глубже (инструменты аудита, Pod Security Standards целиком, supply
chain) — в [10_devsecops](../../10_devsecops/).

## Как проходить
1. [01_core](./01_core/) целиком: теория → примеры → упражнения → ответы.
2. Затем [02_policy_engines](./02_policy_engines/) — он опирается на
   admission и PSA из 01_core.

## Когда двигаться дальше
- Можете выдать ServiceAccount минимальные права и проверить их через
  `kubectl auth can-i --as`.
- Можете написать под, проходящий профиль `restricted`.
- Можете объяснить, чем грозит `failurePolicy: Fail` у
  admission-вебхука и как этим управлять.

Дальше — [07_manifests_management](../07_manifests_management/).
