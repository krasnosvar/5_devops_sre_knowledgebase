# 09.2. Argo CD

## Зачем
Argo CD — самый распространённый GitOps-агент: один CRD `Application`
описывает, откуда брать манифесты и куда их применять, а веб-UI
показывает дерево ресурсов, дрейф и diff. На нём строят доставку от
одного сервиса до сотен приложений в десятках кластеров
(ApplicationSet).

## Пререквизиты
- [01_theory общей темы](../01_theory/gitops.md) — push/pull,
  reconciliation, drift.
- [07_manifests_management/03_kustomize](../../07_manifests_management/03_kustomize/)
  — оверлеи, которые деплоятся в упражнении 02.
- Git и fork репозитория на GitHub — см.
  [01_git_essentials](../../../../4_python_my_knowledgebase/0_tooling_and_workflow/01_git_essentials/)
  (в соседнем репозитории).

## Файлы
- [01_theory/argocd.md](./01_theory/argocd.md) — Application,
  App-of-Apps, ApplicationSet (`goTemplate` + `templatePatch`),
  SyncWaves, Argo CD и Helm, мягкая и жёсткая мультиарендность.
- [02_examples/argocd-app.yaml](./02_examples/argocd-app.yaml) —
  Application с finalizer'ом и ApplicationSet по окружениям.
- [03_exercises/README.md](./03_exercises/README.md) — 4 упражнения,
  🐳 Tier 1 (kind + Argo CD).
- [04_exercises_answers/](./04_exercises_answers/) —
  [argocd-answers.md](./04_exercises_answers/argocd-answers.md) и
  манифесты `argocd-answer.yaml`.

## Как проходить
1. Теория.
2. Поднять kind + Argo CD по началу упражнений, поставить CLI
   `argocd`.
3. Упражнения 01-04, сверка с ответами.

## Когда двигаться дальше
- Можете объяснить разницу `automated`, `prune` и `selfHeal`.
- Пишете ApplicationSet с git directories generator.
- Знаете, зачем `sync-wave` и почему без неё CR может примениться
  раньше своего CRD.

Дальше — [03_fluxcd](../03_fluxcd/).
