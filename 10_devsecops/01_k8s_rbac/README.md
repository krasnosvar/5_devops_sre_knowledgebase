# 01. Kubernetes RBAC

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — команды и шаблоны одним экраном.

## Зачем
По умолчанию в кластерах легко раздать `cluster-admin` всем подряд —
и тогда утечка одного токена ServiceAccount означает захват кластера.
Тема учит давать людям и приложениям ровно те права, которые им нужны,
и регулярно проверять, у кого какие права уже есть.

## Пререквизиты
- [4_kubernetes/06_security](../../4_kubernetes/06_security/) — базовые
  объекты RBAC (Role, RoleBinding, ServiceAccount).
- [0_lab_setup/03_local_k8s](../../0_lab_setup/03_local_k8s/) — kind
  кластер для упражнений.

## Файлы
- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: can-i, роли, аудит прав.
- [01_theory/k8s_rbac_deep.md](./01_theory/k8s_rbac_deep.md) —
  аутентификация vs авторизация, встроенные ClusterRoles,
  resourceNames, аудит, антипаттерны, kubeconfig для пользователя.
- [02_examples/audit-rbac.sh](./02_examples/audit-rbac.sh) — скрипт
  аудита: cluster-admin bindings, широкие права, root/privileged Pod'ы.
- [03_exercises/README.md](./03_exercises/README.md) — 4 упражнения,
  🐳 Tier 1 (kind).
- [04_exercises_answers/](./04_exercises_answers/) — разбор
  [rbac-answers.md](./04_exercises_answers/rbac-answers.md) и манифесты
  `alice-rbac.yaml`, `myapp-rbac.yaml`, `fixed-rbac.yaml`.

## Как проходить
1. Прочитать теорию, особенно антипаттерны.
2. Запустить `audit-rbac.sh` на своём kind кластере.
3. Сделать упражнения, затем сверить с ответами.

## Когда двигаться дальше
- Можете объяснить разницу ClusterRole + RoleBinding и ClusterRoleBinding.
- Можете без подсказки создать пользователя через CSR и ограничить его
  одним namespace.
- Можете найти, кто в кластере имеет доступ к secrets.

Далее: [02_secrets_management](../02_secrets_management/).
