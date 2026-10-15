# 09. GitOps: Argo CD, Flux, Argo Rollouts

## Зачем
При push-деплое CI держит ключи от прод-кластера, а после зелёного
пайплайна никто не следит, что в кластере осталось то же самое. GitOps
переворачивает схему: желаемое состояние лежит в Git, агент внутри
кластера сам забирает его и непрерывно сверяет с реальностью — ручные
правки видны как дрейф, откат делается `git revert`. Это каноническое
место GitOps в базе: CI-сторона (как пайплайн обновляет тег и
продвигает релиз) — в [6_cicd/05_gitops_cd](../../6_cicd/05_gitops_cd/).

## Пререквизиты
- [07_manifests_management](../07_manifests_management/) — Helm-чарты и
  Kustomize-оверлеи: именно их рендерят и применяют GitOps-агенты.
- Git: коммиты, ветки, fork, Pull Request. Git в этой базе не
  преподаётся — см.
  [01_git_essentials](../../../4_python_my_knowledgebase/0_tooling_and_workflow/01_git_essentials/)
  в соседнем репозитории.

> **Забегание вперёд.** Теория опирается на reconcile loop, который
> подробно разбирается в
> [11_operators_and_crds](../11_operators_and_crds/). Для этой темы
> достаточно: контроллер в цикле сравнивает желаемое состояние с
> фактическим и устраняет разницу. Argo CD, Flux и Argo Rollouts
> ставятся как набор CRD + контроллеры — это нормально применять "как
> есть", не зная деталей устройства операторов.

## Файлы
- [01_theory/gitops.md](./01_theory/gitops.md) — четыре принципа,
  push vs pull, reconciliation (Sync vs Health), drift и
  самовосстановление, Image Updater, секреты в GitOps.
- [02_argocd/](./02_argocd/) — Application, ApplicationSet,
  App-of-Apps, SyncWaves, мультиарендность; упражнения и ответы.
- [03_fluxcd/](./03_fluxcd/) — GitRepository + Kustomization,
  HelmRelease, Image Automation; Flux vs Argo CD.
- [04_argo_rollouts/](./04_argo_rollouts/) — Canary с
  AnalysisTemplate, Blue/Green.

## Как проходить
1. Общая теория [01_theory/gitops.md](./01_theory/gitops.md).
2. [02_argocd](./02_argocd/): теория → примеры → упражнения (🐳 kind) →
   ответы.
3. [03_fluxcd](./03_fluxcd/) — теория и примеры, сравнить с Argo CD.
4. [04_argo_rollouts](./04_argo_rollouts/) — теория и пример.

## Когда двигаться дальше
- Можете объяснить, чем pull-модель безопаснее push и что она не
  решает.
- Различаете Sync status и Health status и знаете, почему приложение
  может быть `Synced` и `Degraded` одновременно.
- Без подсказки создаёте Argo CD Application с `selfHeal` и
  наблюдаете откат ручного изменения.
- Знаете, почему HPA и `selfHeal` конфликтуют за `replicas` и как
  это лечится.

Дальше — [10_pod_autoscaling](../10_pod_autoscaling/).
