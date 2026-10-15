# Ответы — GitOps / ArgoCD

Манифесты всех ответов — [`argocd-answer.yaml`](./argocd-answer.yaml)
(разделены `---`, применять можно по одному, вырезав нужный документ).
Стенд поднят по шагам из [`../03_exercises/README.md`](../03_exercises/README.md).
CLI `argocd` ставится отдельно (бинарник из GitHub Releases проекта) и
логинится через port-forward:

```bash
argocd login localhost:8080 --username admin --insecure \
  --password "$(kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath='{.data.password}' | base64 -d)"
```

## Упражнение 01 — Первое приложение в ArgoCD

Application смотрит на каталог `guestbook` в публичном репозитории
`argoproj/argocd-example-apps` (первый документ в `argocd-answer.yaml`).
Чтобы проверить реакцию на коммит, сделайте fork, подставьте свой
`repoURL` и поменяйте, например, `replicas` в
`guestbook/guestbook-ui-deployment.yaml`.

```bash
kubectl apply -f application.yaml      # первый документ из argocd-answer.yaml
argocd app sync myapp
argocd app get myapp
```

Ожидаемый вывод (примерно так):

```text
Name:               argocd/myapp
Sync Policy:        Automated (Prune)
Sync Status:        Synced to HEAD (8088f4c)
Health Status:      Healthy

GROUP  KIND        NAMESPACE  NAME          STATUS  HEALTH
apps   Deployment  guestbook  guestbook-ui  Synced  Healthy
       Service     guestbook  guestbook-ui  Synced  Healthy
```

Почему так: с `syncPolicy.automated` ручной `argocd app sync` не нужен —
он лишь запускает синхронизацию сразу, не дожидаясь опроса Git (по
умолчанию раз в ~3 минуты). После коммита в fork статус на короткое время
станет `OutOfSync`, затем снова `Synced` уже на новом SHA.

## Упражнение 02 — Задеплоить Kustomize overlay через ArgoCD

Второй документ в `argocd-answer.yaml`: `repoURL` — ваш fork этого
репозитория, `path` — от корня репозитория:
`4_kubernetes/07_manifests_management/03_kustomize/02_examples/overlays/prod`.

```bash
kubectl apply -f application.yaml      # второй документ
argocd app sync myapp-kustomize
argocd app manifests myapp-kustomize > /tmp/argo.yaml
kubectl kustomize 4_kubernetes/07_manifests_management/03_kustomize/02_examples/overlays/prod/ > /tmp/local.yaml
argocd app get myapp-kustomize
```

Ожидаемый вывод (примерно так):

```text
Sync Status:        Synced to HEAD (...)
Health Status:      Degraded
...
apps  Deployment  myapp-prod  myapp  Synced  Degraded
```

Почему так: Argo CD находит `kustomization.yaml` в каталоге и сам
вызывает `kustomize build` — никаких плагинов не нужно, а манифесты в
`/tmp/argo.yaml` совпадают с локальным рендером (с точностью до порядка
и служебных label'ов). `Degraded` — ожидаемо: образа `myapp:v1.4.2` не
существует, Pod'ы в `ImagePullBackOff`. Это наглядный пример того, что
`Synced` (кластер = Git) и `Healthy` (всё работает) — разные статусы.

## Упражнение 03 — Self-heal и drift detection

`selfHeal: true` уже включён в Application из упражнения 01.

```bash
kubectl -n guestbook scale deploy guestbook-ui --replicas=5
kubectl -n guestbook get deploy guestbook-ui
sleep 15
kubectl -n guestbook get deploy guestbook-ui
kubectl -n argocd get application myapp \
  -o jsonpath='{.status.operationState.operation.initiatedBy}{"\n"}'
```

Ожидаемый вывод (примерно так):

```text
deployment.apps/guestbook-ui scaled
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
guestbook-ui   1/1     1            1           61s
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
guestbook-ui   1/1     1            1           76s
{"automated":true}
```

Почему так: Argo CD следит за live-объектами через watch, поэтому дрейф
замечается почти сразу, а не на следующем опросе Git. `selfHeal`
запускает синхронизацию автоматически (`initiatedBy: automated`), и
`replicas` возвращается к значению из Git — 1. Без `selfHeal`
приложение просто осталось бы в `OutOfSync`.

## Упражнение 04 — ApplicationSet

Третий документ в `argocd-answer.yaml`: git directories generator
перебирает каталоги `.../overlays/*` и создаёт по Application на
каждый.

```bash
kubectl apply -f applicationset.yaml   # третий документ
kubectl -n argocd get applicationset myapp-overlays \
  -o jsonpath='{.status.conditions[*].message}{"\n"}'
kubectl -n argocd get applications
```

Ожидаемый вывод (примерно так):

```text
All applications have been generated successfully ...
NAME         SYNC STATUS   HEALTH STATUS
myapp        Synced        Healthy
myapp-dev    OutOfSync     Missing
myapp-prod   OutOfSync     Missing
```

Почему так: генератор отдаёт для каждого найденного каталога параметры
`.path.path` и `.path.basename`, шаблон подставляет их в имя, путь и
namespace. Автосинк в ApplicationSet намеренно не включён, поэтому
приложения созданы в `OutOfSync` — синхронизация вручную
(`argocd app sync myapp-dev`). Новый каталог `overlays/stage` в Git сам
превратится в Application `myapp-stage`.

Уборка:

```bash
kubectl -n argocd delete applicationset myapp-overlays
kubectl -n argocd delete application myapp myapp-kustomize
```
