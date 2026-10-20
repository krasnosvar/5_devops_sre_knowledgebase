# 05. Pod Security

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — команды и шаблоны одним экраном.

## Зачем
Даже идеальный образ можно запустить как root, с privileged и
hostPath — и тогда побег из контейнера становится тривиальным. Тема —
каноническое место про Pod Security Standards / Pod Security Admission
в этой базе, плюс securityContext, capabilities, seccomp и policy
engines для правил сверх стандарта.

## Пререквизиты
- [3_containers/05_security](../../3_containers/05_security/) —
  capabilities, seccomp, rootless на уровне контейнера.
- [4_kubernetes/06_security](../../4_kubernetes/06_security/) — краткое
  описание PSS и упражнение с ним.
- [1_linux_and_shell/09_linux_security](../../1_linux_and_shell/09_linux_security/)
  — capabilities и seccomp на уровне ядра.

## Файлы
- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: PSA labels, securityContext.
- [01_theory/pod_security.md](./01_theory/pod_security.md) — уровни
  PSS, режимы PSA, labels и фиксация версии, exemptions, миграция с PSP,
  securityContext, capabilities, seccomp, Kyverno/Gatekeeper.
- [02_examples/secure-pod.yaml](./02_examples/secure-pod.yaml) —
  namespace с restricted, Deployment, проходящий restricted, и Kyverno
  политика.
- Упражнений нет: упражнение по PSS есть в
  [4_kubernetes/06_security/01_core](../../4_kubernetes/06_security/01_core/03_exercises/README.md).

## Как проходить
1. Прочитать раздел PSS/PSA, затем securityContext.
2. Применить `secure-pod.yaml` в kind кластере; убрать из Deployment
   `runAsNonRoot` и посмотреть, как ReplicaSet не может создать Pod.
3. Попробовать `kubectl label --dry-run=server` на своём namespace.

## Когда двигаться дальше
- Можете объяснить разницу enforce/audit/warn и почему enforce не
  проверяет Deployment.
- Можете объяснить, зачем фиксировать `enforce-version`.
- Можете перечислить, что PSP делала, а PSA не делает.

Далее: [06_supply_chain](../06_supply_chain/).
