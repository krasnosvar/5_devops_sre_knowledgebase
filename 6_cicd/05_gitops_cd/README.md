# 05. GitOps глазами CI

## Зачем
При переходе на GitOps пайплайн перестаёт делать `kubectl apply`: он
собирает образ и меняет тег в Git, а деплоит агент в кластере. На работе
это значит — обновлять тег в Ops-репозитории без гонок, продвигать релиз
dev → stage → prod через merge request и откатываться `git revert`.

GitOps-агенты (ArgoCD, Flux), drift, секреты в GitOps — канонический
раздел [4_kubernetes/09_gitops](../../4_kubernetes/09_gitops/); здесь
только CI-сторона.

## Пререквизиты
-  [02_gitlab_ci](../02_gitlab_ci/) или
  [03_github_actions](../03_github_actions/)
  — пайплайны, переменные, ручные джобы.
- [4_kubernetes/07_manifests_management](../../4_kubernetes/07_manifests_management/)
  — Kustomize overlays (`kustomize edit set image`).
- [4_kubernetes/09_gitops](../../4_kubernetes/09_gitops/) — что делает
  GitOps-агент с коммитом, который сделал CI.

## Файлы
- [01_theory/gitops_cd.md](./01_theory/gitops_cd.md) — граница CI и CD,
  push vs pull для пайплайна, App Repo vs Ops Repo, обновление тега из
  CI, promotion, rollback, вопросы с собеседований.
- [02_examples/.gitlab-ci-gitops.yml](./02_examples/.gitlab-ci-gitops.yml)
  — пайплайн: сборка образа → коммит тега в `envs/dev` Ops-репо (с
  повтором при гонке) → ручная джоба, создающая MR на stage.

Без упражнений: лаба требует кластер с агентом GitOps — она есть в
[4_kubernetes/09_gitops/02_argocd](../../4_kubernetes/09_gitops/02_argocd/).

## Как проходить
1. Теория.
2. Разобрать пример: какие права у токена, что будет при одновременном
   пуше, где ручной аппрув.
3. По желанию — подключить пример к Ops-репо из лабы ArgoCD и проверить
   цепочку «коммит CI → синхронизация».

## Когда двигаться дальше
- Можете объяснить, почему тег `latest` ломает GitOps.
- Можете описать promotion через папки окружений и MR.
- Можете объяснить, почему «зелёная» джоба обновления тега не означает
  успешный деплой и как узнать реальный статус.

Дальше: [06_testing_in_pipelines](../06_testing_in_pipelines/).
