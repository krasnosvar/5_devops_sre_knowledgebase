# 07. Управление манифестами: Helm и Kustomize

## Зачем
Один `deployment.yaml` легко применить руками. Когда окружений три
(dev/stage/prod), сервисов десятки, а между окружениями отличаются
реплики, теги образов и конфиги, копипаста YAML превращается в
источник дрейфа и ошибок. Тема даёт базовую механику применения
манифестов (labels, Client-Side vs Server-Side Apply, `dry-run`/`diff`)
и два стандартных инструмента параметризации: шаблоны (Helm) и патчи
поверх базы (Kustomize). Именно их результат потом доставляет GitOps.

## Пререквизиты
- [00_first_steps](../00_first_steps/) — `kubectl apply`, kind-кластер.
- [02_workloads](../02_workloads/) — Deployment, Service, ConfigMap: их
  и будем шаблонизировать и патчить.

## Файлы
- [01_theory/manifests_management.md](./01_theory/manifests_management.md)
  — анатомия манифеста, labels vs annotations, Client-Side vs
  Server-Side Apply, `--dry-run=client/server`, `kubectl diff`,
  multi-document YAML, зачем вообще Helm/Kustomize.
- [02_helm/](./02_helm/) — подтема Helm: теория, пример чарта `myapp`,
  helmfile, упражнения и ответы.
- [03_kustomize/](./03_kustomize/) — подтема Kustomize: base/overlays,
  ConfigMapGenerator, Strategic Merge vs JSON Patch, `$patch: delete`,
  упражнения и ответы.

Своих примеров и упражнений у общей части нет — практика целиком в
подтемах.

## Как проходить
1. Общая теория [01_theory](./01_theory/manifests_management.md).
2. [02_helm](./02_helm/): теория → пример → упражнения → ответы.
3. [03_kustomize](./03_kustomize/): то же самое; в конце теории —
   связка Kustomize + Helm (`helmCharts`).

## Когда двигаться дальше
- Можете объяснить, какие ошибки ловит `--dry-run=server`, но не
  `--dry-run=client`, и чем `kubectl diff` отличается от
  `helm template`.
- Без подсказки пишете простой чарт и проверяете его `helm lint` и
  `helm template`, умеете откатить релиз.
- Собираете base + overlays в Kustomize и проверяете результат
  `kubectl kustomize`.
- Можете объяснить, когда выбрать Helm, а когда Kustomize.

Дальше — [08_cluster_operations](../08_cluster_operations/):
эксплуатация самого кластера. Результат этой темы (чарты и оверлеи)
напрямую используется в [09_gitops](../09_gitops/).
