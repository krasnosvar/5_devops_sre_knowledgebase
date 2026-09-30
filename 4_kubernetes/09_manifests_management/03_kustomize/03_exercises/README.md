# Упражнения — Kustomize (base/overlays)

Стенд: 🐳 Tier 1 — kind или k3d кластер

```bash
kind create cluster --name manifests-lab
```

## 01 — Собрать base + overlay и посмотреть на разницу окружений

**Задача:** Отрендерить `base` без изменений, затем `overlays/dev` и `overlays/prod` — сравнить итоговый YAML.

```bash
cd ../02_examples

kubectl kustomize base/ | head -30

kubectl kustomize overlays/dev/ > /tmp/dev.yaml
kubectl kustomize overlays/prod/ > /tmp/prod.yaml
diff /tmp/dev.yaml /tmp/prod.yaml

# Обрати внимание: у ConfigMap в dev и prod разные имена (с хэш-суффиксом) —
# это работа configMapGenerator, а не ручная правка
```

## 02 — ConfigMapGenerator и автоматический Rolling Update

**Задача:** Убедиться, что при изменении конфига в overlay меняется имя ConfigMap и Deployment получает новый Rolling Update без ручных действий.

```bash
kubectl apply -k overlays/dev/ --dry-run=client -o yaml | grep -A2 "kind: ConfigMap"

# TODO: поменяй LOG_LEVEL в overlays/dev/kustomization.yaml на другое значение
# и снова отрендери — сравни имя ConfigMap (SHA-суффикс должен измениться)
kubectl kustomize overlays/dev/ | grep -A2 "kind: ConfigMap"
```

## 03 — Удалить ресурс из base через `$patch: delete`

**Задача:** В `overlays/dev/` Ingress не нужен (используется port-forward для локальной разработки). Убрать его, не трогая `base/`.

```bash
# TODO: создай overlays/dev/patch-delete-ingress.yaml с содержимым:
#   $patch: delete
#   apiVersion: networking.k8s.io/v1
#   kind: Ingress
#   metadata:
#     name: myapp
#
# Важно: $patch: delete должен быть ВЕРХНЕУРОВНЕВЫМ ключом (соседом apiVersion/kind),
# а не вложенным в metadata — иначе Kustomize молча проигнорирует директиву.
#
# и добавь его в patches: overlays/dev/kustomization.yaml

kubectl kustomize overlays/dev/ | grep -c "kind: Ingress"   # должно быть 0
kubectl kustomize overlays/prod/ | grep -c "kind: Ingress"  # должно остаться 1 — base не менялся
```

## 04 — JSON Patch: точечное изменение аргумента запуска

**Задача:** В `overlays/prod/` добавить контейнеру аргумент `--verbose=false`, не трогая остальную структуру `args` через Strategic Merge (предположим что args — позиционный массив без имён, где Strategic Merge неудобен).

```bash
# TODO: добавь в overlays/prod/kustomization.yaml патч типа JSON Patch:
#   patches:
#     - target:
#         kind: Deployment
#         name: myapp
#       patch: |-
#         - op: add
#           path: /spec/template/spec/containers/0/args
#           value: ["--verbose=false"]

kubectl kustomize overlays/prod/ | grep -A3 "args:"
```

Готовое решение: упражнение 03 — в `../04_exercises_answers/overlays/dev/`,
упражнение 04 — в `../04_exercises_answers/overlays/prod/`.
