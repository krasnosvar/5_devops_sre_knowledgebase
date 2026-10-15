# 09.3. Flux CD

## Зачем
Flux — второй основной GitOps-инструмент: набор небольших контроллеров
(source, kustomize, helm, image automation) вместо одного монолита и
без обязательного UI. Встречается там, где GitOps настраивают целиком
декларативно и собирают из нужных частей; полезно понимать, чем он
отличается от Argo CD, чтобы осознанно выбирать.

## Пререквизиты
- [01_theory общей темы](../01_theory/gitops.md).
- [02_argocd](../02_argocd/) — для сравнения моделей ресурсов.
- [07_manifests_management](../../07_manifests_management/) — Helm и
  Kustomize, которые применяет Flux.

## Файлы
- [01_theory/fluxcd.md](./01_theory/fluxcd.md) — архитектура GitOps
  Toolkit, GitRepository + Kustomization, HelmRepository + HelmRelease,
  Image Automation (`image.toolkit.fluxcd.io/v1`), Flux vs Argo CD.
- [02_examples/gitrepository-kustomization.yaml](./02_examples/gitrepository-kustomization.yaml)
  — GitRepository, Kustomization, ImageRepository, ImagePolicy,
  ImageUpdateAutomation.
- [02_examples/helmrelease.yaml](./02_examples/helmrelease.yaml) —
  HelmRepository + HelmRelease (чарт podinfo) с remediation.

Своих упражнений нет: GitOps-практика собрана в
[02_argocd](../02_argocd/03_exercises/README.md). Желающие могут
повторить те же сценарии на Flux: `flux install` на kind и примеры из
`02_examples/` со своим fork'ом вместо `org/gitops-config`.

## Как проходить
1. Теория.
2. Прочитать оба примера и сопоставить каждый ресурс с аналогом в
   Argo CD.
3. Interview Q&A в конце теории.

## Когда двигаться дальше
- Можете объяснить, зачем Flux делит "откуда" (GitRepository,
  HelmRepository) и "что применять" (Kustomization, HelmRelease).
- Знаете, как Flux коммитит новый тег образа обратно в Git.
- Можете аргументированно выбрать Flux или Argo CD для команды.

Дальше — [04_argo_rollouts](../04_argo_rollouts/).
