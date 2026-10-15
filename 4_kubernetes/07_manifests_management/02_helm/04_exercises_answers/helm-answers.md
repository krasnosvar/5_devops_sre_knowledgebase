# Ответы — Helm

Все команды выполняются из каталога
`4_kubernetes/07_manifests_management/02_helm/` этого репозитория,
кластер — kind (см. [`../03_exercises/README.md`](../03_exercises/README.md)).
Эталонный чарт — [`../02_examples/myapp/`](../02_examples/myapp/), values
для продакшена — [`values-prod.yaml`](./values-prod.yaml).

## Упражнение 01 — Написать chart с нуля

```bash
# Скелет: посмотреть, что генерирует helm create
helm create /tmp/helm-lab/myapp
ls /tmp/helm-lab/myapp/templates

# Удалить лишнее
rm -rf /tmp/helm-lab/myapp/templates/tests/ \
  /tmp/helm-lab/myapp/templates/hpa.yaml \
  /tmp/helm-lab/myapp/templates/serviceaccount.yaml
```

Упрощённый результат (Deployment + Service, в values — `replicaCount`,
`image.*`, `service.*`, `resources`) лежит в `02_examples/myapp/`.
Дальше работаем с ним:

```bash
helm lint ./02_examples/myapp
helm template myapp ./02_examples/myapp | head -20

helm install myapp ./02_examples/myapp --set replicaCount=2 --wait

kubectl get pods -l app.kubernetes.io/instance=myapp
helm list
```

Ожидаемый вывод (примерно так):

```text
==> Linting ./02_examples/myapp
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed
---
# Source: myapp/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-myapp
...
NAME                          READY   STATUS    RESTARTS   AGE
myapp-myapp-fcc965965-ffc8m   1/1     Running   0          22s
myapp-myapp-fcc965965-nsk4d   1/1     Running   0          22s
NAME   NAMESPACE  REVISION  UPDATED  STATUS    CHART        APP VERSION
myapp  default    1         ...      deployed  myapp-0.1.0  1.0.0
```

Почему так: `helm template` рендерит локально без кластера — так ловятся
ошибки шаблонов до установки. Имя `myapp-myapp` = `<release>-<chart>`
из `_helpers.tpl`; у чарта от `helm create` хелпер умнее и при
совпадении имён даёт просто `myapp`, поэтому проверяем по label
`app.kubernetes.io/instance`, а не по имени.

## Упражнение 02 — Обновить и откатить релиз

```bash
helm upgrade myapp ./02_examples/myapp --set image.tag=1.25 --wait
helm history myapp
helm rollback myapp 1 --wait

kubectl get deploy -l app.kubernetes.io/instance=myapp \
  -o jsonpath='{.items[0].spec.template.spec.containers[0].image}{" "}{.items[0].spec.replicas}{"\n"}'
helm history myapp
```

Ожидаемый вывод (примерно так):

```text
REVISION  STATUS      CHART        APP VERSION  DESCRIPTION
1         superseded  myapp-0.1.0  1.0.0        Install complete
2         deployed    myapp-0.1.0  1.0.0        Upgrade complete
Rollback was a success! Happy Helming!
nginx:alpine 2
REVISION  STATUS      CHART        APP VERSION  DESCRIPTION
1         superseded  myapp-0.1.0  1.0.0        Install complete
2         superseded  myapp-0.1.0  1.0.0        Upgrade complete
3         deployed    myapp-0.1.0  1.0.0        Rollback to 1
```

Почему так: rollback не "отматывает" историю, а создаёт новую ревизию 3
с манифестами ревизии 1. Подвох: `helm upgrade` без `--reuse-values`
берёт values заново из чарта, поэтому в ревизии 2 `replicaCount`
вернулся к 1 (значение из `values.yaml`), а откат на ревизию 1 вернул и
тег `alpine`, и 2 реплики.

## Упражнение 03 — Helm из публичного репозитория

```bash
helm repo add podinfo https://stefanprodan.github.io/podinfo
helm repo update
helm show values podinfo/podinfo | head -30

helm install my-podinfo podinfo/podinfo \
  --set replicaCount=2 \
  --set ui.message="Hello from Helm" \
  --create-namespace -n demo \
  --wait

kubectl get pods -n demo
helm list -n demo

kubectl -n demo port-forward svc/my-podinfo 9898:9898 &
curl -s localhost:9898 | grep message
kill %1
```

Ожидаемый вывод (примерно так):

```text
# Default values for podinfo.

replicaCount: 1
...
NAME                          READY   STATUS    RESTARTS   AGE
my-podinfo-684799475d-qzt4g   1/1     Running   0          20s
my-podinfo-684799475d-wpt7k   1/1     Running   0          20s
NAME        NAMESPACE  REVISION  STATUS    CHART           APP VERSION
my-podinfo  demo       1         deployed  podinfo-6.15.0  6.15.0
  "message": "Hello from Helm",
```

Почему так: `helm show values` — главный способ узнать, какие ключи
вообще можно переопределить (`--set` с несуществующим ключом молча
игнорируется). `--create-namespace -n demo` держит релиз в отдельном
namespace — там же лежит Secret с историей релиза. Почему здесь не
Bitnami — см. примечание в тексте упражнения.

## Упражнение 04 — helm diff

```bash
helm plugin install https://github.com/databus23/helm-diff
# если плагин не загружается на вашей версии Helm:
# helm plugin install https://github.com/databus23/helm-diff --version v3.11.0

helm diff upgrade my-podinfo podinfo/podinfo \
  --reuse-values --set ui.message="Hello v2" \
  -n demo --context 1
```

Ожидаемый вывод (примерно так):

```text
demo, my-podinfo, Deployment (apps) has changed:
...
-             value: "Hello from Helm"
+             value: "Hello v2"
...
```

Почему так: `helm diff` сравнивает манифесты текущего релиза с тем, что
получится после upgrade, и показывает только изменившиеся строки
(`--context 1` — одна строка контекста вокруг изменения). Без
`--reuse-values` diff показал бы ещё и откат `replicaCount` к 1.

Уборка:

```bash
helm uninstall myapp
helm uninstall my-podinfo -n demo
kubectl delete namespace demo
```
