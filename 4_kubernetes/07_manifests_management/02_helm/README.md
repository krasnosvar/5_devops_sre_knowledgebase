# 07.2. Helm

## Зачем
Helm — пакетный менеджер Kubernetes: один шаблонный чарт + разные
`values.yaml` на окружение, плюс история релизов с откатом. Через Helm
ставится почти весь сторонний софт (мониторинг, ingress-контроллеры,
операторы), и в нём же обычно упаковывают свои сервисы.

## Пререквизиты
- [01_theory общей темы](../01_theory/manifests_management.md) —
  `apply`, `dry-run`, `diff`.
- [02_workloads](../../02_workloads/) — Deployment и Service, из
  которых состоит пример чарта.

## Файлы
- [01_theory/helm.md](./01_theory/helm.md) — релизы в Secret,
  3-way merge, зависимости, хуки, секреты, плагины (helm-diff,
  helm-secrets, helm-unittest).
- [02_examples/](./02_examples/) — чарт [`myapp/`](./02_examples/myapp/)
  (Deployment + Service, `_helpers.tpl`), `helmfile.yaml.gotmpl`
  (несколько релизов, окружения, `needs`).
- [03_exercises/README.md](./03_exercises/README.md) — 4 упражнения,
  🐳 Tier 1 (kind).
- [04_exercises_answers/](./04_exercises_answers/) —
  [helm-answers.md](./04_exercises_answers/helm-answers.md) и
  `values-prod.yaml`.

## Как проходить
1. Теория.
2. Прочитать чарт `02_examples/myapp/`, отрендерить его
   `helm template`.
3. Упражнения 01-04 на kind, затем сверка с ответами.

## Когда двигаться дальше
- Можете объяснить, где Helm хранит релиз и что делает
  `helm rollback`.
- Знаете, почему `helm upgrade` без `--reuse-values` сбрасывает
  ранее переданные `--set`.
- Можете посмотреть изменения до обновления через `helm diff`.

Дальше — [03_kustomize](../03_kustomize/).
