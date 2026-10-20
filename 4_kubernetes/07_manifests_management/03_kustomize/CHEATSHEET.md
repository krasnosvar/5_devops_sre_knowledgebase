# Kustomize — шпаргалка

Подробности и объяснения — в [kustomize.md](./01_theory/kustomize.md).
⚠️ — опасная команда или частая ловушка.

## Команды

| Задача | Команда |
| :--- | :--- |
| Собрать итоговый YAML | `kubectl kustomize overlays/prod` (или `kustomize build overlays/prod`) |
| Применить | `kubectl apply -k overlays/prod` |
| Diff с кластером | `kubectl diff -k overlays/prod` |
| Удалить всё, что описано ⚠️ | `kubectl delete -k overlays/prod` |
| Сборка с `helmCharts` | `kustomize build --enable-helm overlays/prod` (или `kubectl kustomize --enable-helm`) |
| Поменять тег образа (CI) | `cd overlays/prod && kustomize edit set image myapp=registry.example.com/myapp:v1.5.0` |
| Добавить ресурс в kustomization | `kustomize edit add resource service.yaml` |
| Задать namespace | `kustomize edit set namespace myapp-prod` |
| Перевести устаревшие поля (`patchesStrategicMerge`, `commonLabels`, `bases`) | `kustomize edit fix` |
| Проверить сборку всех оверлеев | `for d in overlays/*/; do kubectl kustomize "$d" >/dev/null \|\| echo "FAIL $d"; done` |

⚠️ Версия Kustomize внутри `kubectl` отстаёт от standalone `kustomize`:
сверяйте `kubectl version --client` и `kustomize version`.

## Структура base / overlays

```text
base/       kustomization.yaml, deployment.yaml, service.yaml
overlays/
  dev/      kustomization.yaml (resources: [../../base]) + патчи
  prod/     kustomization.yaml + патчи
```

## Поля kustomization.yaml

| Поле | Что делает |
| :--- | :--- |
| `resources: [../../base, ingress.yaml]` | что собрать (файлы, каталоги, удалённые URL) |
| `namespace: myapp-prod` | проставить namespace всем ресурсам |
| `namePrefix: prod-` / `nameSuffix: -v2` | переименовать с обновлением ссылок |
| `labels: [{pairs: {env: prod}, includeSelectors: false}]` | добавить labels; `commonLabels` устарел и меняет селекторы ⚠️ |
| `images: [{name: myapp, newName: ..., newTag: v1.4.2}]` | заменить образ без патча |
| `replicas: [{name: myapp, count: 3}]` | задать число реплик |
| `configMapGenerator` / `secretGenerator` | создать ConfigMap/Secret с хэшем в имени |
| `generatorOptions: {disableNameSuffixHash: true}` | отключить хэш (теряется авто-rollout) |
| `patches:` | strategic merge или JSON 6902 патчи |
| `helmCharts:` | отрендерить чарт (нужен `--enable-helm`) |

## Генераторы

```yaml
configMapGenerator:
  - name: myapp-config
    literals: [LOG_LEVEL=info]
    files: [app.properties]
```

| Свойство | Значение |
| :--- | :--- |
| Имя результата | `myapp-config-<hash>`, ссылки в Deployment переписываются |
| Смена конфига | новое имя → новый pod template → Rolling Update |
| Старые ConfigMap | остаются в кластере; чистить через `prune` (GitOps) |

## Патчи: что выбрать

| Ситуация | Тип патча |
| :--- | :--- |
| Поменять поле контейнера по имени, добавить env/ресурсы | Strategic Merge (кусок YAML с `kind` + `metadata.name`) |
| Позиционный массив без имён (`args`), точечная операция | JSON Patch (RFC 6902) с `target` |
| Один патч на много объектов | `target: {kind: Deployment, labelSelector: "tier=web"}` |
| Убрать ресурс из base | `$patch: delete` верхнеуровневым ключом |

```yaml
patches:
  - path: patch-replicas.yaml          # strategic merge
  - target: {kind: Deployment, name: myapp}
    patch: |-
      - op: add
        path: /spec/template/spec/containers/0/args
        value: ["--verbose=false"]
```

```yaml
# delete-ingress.yaml — подключить через patches: [{path: ...}]
$patch: delete
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
```

## Ловушки

| Симптом | Причина |
| :--- | :--- |
| Ресурс не удалился, ошибок нет | `$patch: delete` вложен в `metadata`, а не на верхнем уровне |
| `security; file '...' is not in or below '...'` | файл вне каталога kustomization; по умолчанию `--load-restrictor=LoadRestrictionsRootOnly` |
| Под не перезапустился после правки конфига | ConfigMap описан руками, а не через `configMapGenerator` |
| `helmCharts` молча не рендерится / ошибка | забыт `--enable-helm` или нет `helm` в `PATH` |
| JSON Patch упал `doc is missing path` | неверный индекс/путь; `add` создаёт ключ, `replace` требует существующий |
| После `commonLabels` упал apply Deployment | изменился неизменяемый `spec.selector` |

> Проверка: overlay с `namespace`, `namePrefix`, `labels`, `images`,
> `replicas`, `configMapGenerator`, JSON Patch и `$patch: delete` собран
> `kubectl kustomize` (kubectl v1.34.1); `kustomize edit set image`
> проверен (v5.8.1); не проверено: `helmCharts` с `--enable-helm`.
