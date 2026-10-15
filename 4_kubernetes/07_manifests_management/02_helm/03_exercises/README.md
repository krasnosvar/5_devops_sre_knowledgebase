# Упражнения — Helm

Стенд: 🐳 Tier 1 — kind или k3d кластер

## 01 — Написать chart с нуля

**Задача:** Создать Helm chart для nginx с параметризованным replicas, image, port.
Эталон упрощённого чарта — [`../02_examples/myapp/`](../02_examples/myapp/).

```bash
# Создать скелет
helm create myapp
# Удалить лишнее из templates/
rm -rf myapp/templates/tests/ myapp/templates/hpa.yaml myapp/templates/serviceaccount.yaml

# TODO: упростить deployment.yaml, service.yaml
# В values.yaml оставить: replicaCount, image.tag, service.port

# Проверить рендер
helm template myapp ./myapp

# Установить
helm install myapp ./myapp --set replicaCount=2

# Проверить
kubectl get pods
helm list
```

## 02 — Обновить и откатить релиз

```bash
# Обновить image tag
helm upgrade myapp ./myapp --set image.tag=1.25

# Посмотреть историю
helm history myapp

# Откатить к предыдущей версии
helm rollback myapp 1

# Убедиться что откат применился (селектор по label работает при любом
# имени Deployment: у `helm create` это `myapp`, у эталона — `myapp-myapp`)
kubectl get deploy -l app.kubernetes.io/instance=myapp \
  -o jsonpath='{.items[0].spec.template.spec.containers[0].image}'
```

## 03 — Helm из публичного репозитория

**Задача:** подключить чужой chart-репозиторий, посмотреть его values,
установить релиз с переопределёнными значениями и проверить результат.
Используется небольшой демо-чарт `podinfo` (активно поддерживается, без
внешних зависимостей).

> **Почему не Bitnami.** Раньше в этом упражнении ставился Bitnami
> PostgreSQL. С 2025 года бесплатный каталог Bitnami сильно урезан:
> версионированные образы перенесены в архивный репозиторий
> `bitnamilegacy` без обновлений, а актуальные образы распространяются по
> платной подписке. Чарты по умолчанию ссылаются на эти образы, поэтому
> «просто `helm install`» может не стартовать или поставить
> необновляемый образ. Для PostgreSQL в Kubernetes смотрите на оператор
> CloudNativePG (принцип работы операторов — в
> [`11_operators_and_crds`](../../../11_operators_and_crds/)) или на
> официальный образ `postgres` в собственном чарте/StatefulSet.

```bash
helm repo add podinfo https://stefanprodan.github.io/podinfo
helm repo update

# Показать доступные values
helm show values podinfo/podinfo | head -30

# Установить с кастомными values
helm install my-podinfo podinfo/podinfo \
  --set replicaCount=2 \
  --set ui.message="Hello from Helm" \
  --create-namespace -n demo \
  --wait

# Проверить
kubectl get pods -n demo
helm list -n demo

# Обратиться к приложению
kubectl -n demo port-forward svc/my-podinfo 9898:9898 &
curl -s localhost:9898 | grep message
```

## 04 — helm diff (требует плагин)

```bash
# Установить helm-diff. Если на вашей версии Helm свежий плагин не
# загружается (ошибка `unknown field "platformHooks"`), поставьте версию
# постарше: добавьте --version v3.11.0
helm plugin install https://github.com/databus23/helm-diff

# Посмотреть, что изменится ПЕРЕД обновлением
helm diff upgrade my-podinfo podinfo/podinfo \
  --reuse-values --set ui.message="Hello v2" \
  -n demo
```

Ответы — [`../04_exercises_answers/helm-answers.md`](../04_exercises_answers/helm-answers.md).
