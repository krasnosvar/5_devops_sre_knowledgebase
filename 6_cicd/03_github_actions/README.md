# 03. GitHub Actions

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — команды и шаблоны одним экраном.

## Зачем
GitHub Actions — CI/CD по умолчанию для проектов на GitHub. На работе это
workflow для тестов и сборки, reusable workflows для единого деплоя во
всех репозиториях и OIDC-доступ в облако без статических ключей —
одна из самых частых причин утечек.

## Пререквизиты
- [01_pipeline_theory](../01_pipeline_theory/) — стадии CI/CD и стратегии
  деплоя.
-  [Git:
  основы](../../../4_python_my_knowledgebase/0_tooling_and_workflow/01_git_essentials/)
  (соседний репозиторий) — push, ветки, pull request.
- [3_containers](../../3_containers/) — сборка и публикация образов.

> **Забегание вперёд.** Деплой-джобы используют AWS (OIDC, EKS) и
> `kubectl` — подробно в [7_compute_platforms/02_aws](../../7_compute_platforms/02_aws/)
> и [4_kubernetes](../../4_kubernetes/). Для этой темы достаточно понимать,
> что джоба получает временные AWS-ключи через OIDC и вызывает
> `kubectl set image`. Упражнение 04 (OIDC) требует AWS-аккаунт — его
> можно отложить.

## Файлы
- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: ключи workflow, OIDC, `gh`.
- [01_theory/github_actions.md](./01_theory/github_actions.md) —
  workflows/jobs/steps, custom actions, self-hosted runners (ARC),
  environments и protection rules, OIDC и блок `permissions`, вопросы с
  собеседований.
- [02_examples/ci.yaml](./02_examples/ci.yaml) — полный workflow: lint →
  test (matrix + postgres service) → build/push в GHCR + cosign keyless →
  deploy staging/production через OIDC.
- [03_exercises/README.md](./03_exercises/README.md) — 4 упражнения: hello
  world, matrix, reusable workflow, OIDC. ☁️ Tier 3 (GitHub.com).
- [04_exercises_answers/](./04_exercises_answers/) — ответы:
  [README.md](./04_exercises_answers/README.md) (по упражнениям),
  [ci-answer.yaml](./04_exercises_answers/ci-answer.yaml) и
  [deploy.yaml](./04_exercises_answers/deploy.yaml) (reusable workflow),
  [aws-trust-policy.json](./04_exercises_answers/aws-trust-policy.json)
  (Trust Policy роли для OIDC).

## Как проходить
1. Теория (`01_theory/github_actions.md`).
2. Разобрать `02_examples/ci.yaml`: `needs`, `permissions`, `environment`.
3. Создать публичный репозиторий на GitHub и сделать упражнения 01-03.
4. Упражнение 04 — при наличии AWS-аккаунта.
5. Сверка с ответами.

## Когда двигаться дальше
- Можете объяснить, почему при явном `permissions` джобе с OIDC нужны и
  `id-token: write`, и `contents: read`.
- Можете вынести деплой в reusable workflow и передать в него секреты.
- Можете описать цепочку OIDC: JWT от GitHub → Trust Policy роли →
  временные STS-ключи.

Дальше: [04_secrets_in_pipelines](../04_secrets_in_pipelines/).
