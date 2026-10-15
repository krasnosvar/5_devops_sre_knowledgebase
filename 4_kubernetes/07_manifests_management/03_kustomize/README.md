# 07.3. Kustomize

## Зачем
Kustomize решает ту же задачу "один манифест — несколько окружений",
но без шаблонов: чистый YAML в `base/` и точечные патчи в `overlays/`.
Встроен в `kubectl` (`kubectl apply -k`), из коробки понимается Argo CD
и Flux, поэтому часто используется для собственных сервисов.

## Пререквизиты
- [01_theory общей темы](../01_theory/manifests_management.md).
- [02_helm](../02_helm/) — для сравнения подходов и для раздела про
  `helmCharts`.

## Файлы
- [01_theory/kustomize.md](./01_theory/kustomize.md) — bases/overlays,
  ConfigMapGenerator и автоматический Rolling Update, Strategic Merge
  vs JSON Patch, `$patch: delete`, связка с Helm.
- [02_examples/](./02_examples/) — `base/` (Deployment, Service,
  Ingress, ConfigMapGenerator) и `overlays/dev`, `overlays/prod`.
- [03_exercises/README.md](./03_exercises/README.md) — 4 упражнения,
  🐳 Tier 1 (kind; большая часть — только `kubectl kustomize`).
- [04_exercises_answers/](./04_exercises_answers/) —
  [kustomize-answers.md](./04_exercises_answers/kustomize-answers.md) и
  готовые оверлеи `overlays/dev` (`$patch: delete`), `overlays/prod`
  (JSON Patch).

## Как проходить
1. Теория.
2. `kubectl kustomize` на base и обоих оверлеях из `02_examples/`.
3. Упражнения 01-04, затем сверка с ответами.

## Когда двигаться дальше
- Можете объяснить, почему изменение literal в `configMapGenerator`
  перезапускает поды, а правка обычного ConfigMap — нет.
- Знаете, куда ставить `$patch: delete` и почему вложенный в
  `metadata` он молча игнорируется.
- Выбираете между Strategic Merge и JSON Patch осознанно.

Дальше — [08_cluster_operations](../../08_cluster_operations/); оверлеи
из этой темы деплоятся через Argo CD в
[09_gitops/02_argocd](../../09_gitops/02_argocd/).
