# GitOps

## Что такое GitOps

GitOps — операционная модель где Git является единственным источником правды
для желаемого состояния инфраструктуры и приложений.

**Принципы:**
1. Вся система описана декларативно
2. Желаемое состояние хранится в Git (versioned, auditable)
3. Изменения в Git автоматически применяются к кластеру
4. Агент обнаруживает и исправляет расхождения (drift)

## Push-based vs Pull-based

```
PUSH-BASED (традиционный CD):
  Git → CI/CD pipeline → kubectl apply → k8s
  Минус: CI нужны credentials кластера; нет drift detection

PULL-BASED (GitOps):
  Git → [изменение] → ArgoCD/Flux (в кластере) → kubectl apply
  Плюс: credentials только внутри кластера; drift detection; auto-sync
```

## ArgoCD — архитектура

```
               Git Repository
                    │
              (watches for changes)
                    │
┌───────────────────▼─────────────────────┐
│              ArgoCD                     │
│                                         │
│  Application Controller                 │
│  (сравнивает desired vs live state)     │
│                                         │
│  Repo Server (клонирует Git, рендерит   │
│  Helm/Kustomize/plain YAML)             │
│                                         │
│  API Server (UI + CLI + webhook)        │
└───────────────────┬─────────────────────┘
                    │
              kubectl apply
                    │
             k8s API Server
```

## Application — основной объект ArgoCD

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default

  source:
    repoURL: https://github.com/org/repo.git
    targetRevision: HEAD          # ветка, тег или commit SHA
    path: helm/myapp              # путь к chart/kustomize/yaml

    # Для Helm:
    helm:
      valueFiles:
        - values.yaml
        - values-prod.yaml
      parameters:
        - name: image.tag
          value: "1.2.3"

    # Для Kustomize:
    # kustomize:
    #   images:
    #     - myapp=registry/myapp:1.2.3

  destination:
    server: https://kubernetes.default.svc   # целевой кластер
    namespace: production

  syncPolicy:
    automated:
      prune: true       # удалять ресурсы удалённые из Git
      selfHeal: true    # восстанавливать при ручных изменениях в кластере
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

## ApplicationSet — генерация приложений по шаблону

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: myapp-per-env
spec:
  generators:
    # генератор по списку окружений
    - list:
        elements:
          - env: dev
            cluster: https://dev-cluster.example.com
          - env: staging
            cluster: https://staging-cluster.example.com
          - env: prod
            cluster: https://prod-cluster.example.com

  template:
    metadata:
      name: "myapp-{{env}}"
    spec:
      source:
        repoURL: https://github.com/org/repo.git
        path: "overlays/{{env}}"
        targetRevision: HEAD
      destination:
        server: "{{cluster}}"
        namespace: myapp
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

## Sync Waves — порядок применения ресурсов

```yaml
# применить CRDs до Deployments
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-1"   # отрицательные — первыми
---
# потом namespace
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"
---
# потом deployment
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```

## Promotion pattern — продвижение между окружениями

```
feature-branch → PR → merge в main
                                │
                    ArgoCD sync в dev (автоматически)
                                │
                    Integration tests pass
                                │
                    PR: bump image tag в overlays/staging/
                                │
                    ArgoCD sync в staging
                                │
                    Smoke tests pass + manual approval
                                │
                    PR: bump image tag в overlays/prod/
                                │
                    ArgoCD sync в prod
```

Конкретный image tag меняется через PR — полная история в Git,
rollback = revert PR.

## Image Updater — автоматическое обновление тегов

```yaml
# аннотации на Application для автоматического обновления тега
metadata:
  annotations:
    argocd-image-updater.argoproj.io/image-list: myapp=registry/myapp
    argocd-image-updater.argoproj.io/myapp.update-strategy: semver
    argocd-image-updater.argoproj.io/myapp.allow-tags: regexp:^1\.\d+\.\d+$
    argocd-image-updater.argoproj.io/write-back-method: git   # пишет в Git
```
