# 02. Secrets Management

## Зачем
Пароли в Git, в ConfigMap или в base64 Secret без шифрования etcd —
самые частые причины утечек. Тема показывает, где хранить секреты
(Vault/OpenBao, облачные менеджеры), как доставлять их в Kubernetes
(External Secrets, Sealed Secrets) и как ловить утечки в репозитории.

## Пререквизиты
- [01_k8s_rbac](../01_k8s_rbac/) — доступ к Secret ограничивается RBAC.
- [0_lab_setup/01_docker_compose](../../0_lab_setup/01_docker_compose/) —
  стенд Vault поднимается через Docker Compose.
- Git: используется в упражнении с gitleaks; в этой базе не
  преподаётся, см.
  [01_git_essentials](../../../4_python_my_knowledgebase/0_tooling_and_workflow/01_git_essentials/)
  (соседний репозиторий). Достаточно `git init`, `git add`, `git commit`.

## Файлы
- [01_theory/secrets_management.md](./01_theory/secrets_management.md) —
  почему Secret небезопасен, Vault, External Secrets Operator, Sealed
  Secrets, AWS Secrets Manager + IRSA.
- [02_examples/docker-compose.yml](./02_examples/docker-compose.yml) —
  Vault в dev-режиме для упражнений.
- [03_exercises/README.md](./03_exercises/README.md) — 4 упражнения
  (KV, динамические секреты PostgreSQL, policy, gitleaks), 🐳 Tier 1.
- [04_exercises_answers/vault-answers.md](./04_exercises_answers/vault-answers.md)
  — ответы с ожидаемым выводом.

## Как проходить
1. Теория → поднять Vault (`docker compose up -d` в `02_examples/`).
2. Упражнения 01–03 по порядку (02 использует сеть Compose-стенда).
3. Упражнение 04 — в отдельном временном каталоге, не в этом
   репозитории. Сверить с ответами.

## Когда двигаться дальше
- Можете объяснить, чем динамический секрет лучше статического.
- Можете написать Vault policy для одного приложения и проверить её.
- Знаете порядок действий при утечке секрета в Git (сначала ротация).

Далее: [03_network_policy](../03_network_policy/).
