# GitOps CD — Continuous Delivery через Git

## GitOps vs традиционный CD

```
Традиционный CD (push-based):
  Code → CI → Build → Push Image → kubectl apply / helm upgrade → Cluster
  
  Проблема: CI pipeline нужны credentials кластера.
  Нет гарантии что кластер соответствует желаемому состоянию.
  Нет истории кто что деплоил.

GitOps (pull-based):
  Code → CI → Build → Push Image → Update image tag in git → PR/merge
                                                               ↓
                                                    ArgoCD/Flux (в кластере)
                                                    видит изменение в git
                                                               ↓
                                                    kubectl apply (изнутри кластера)
  
  Преимущества: credentials не покидают кластер.
  Drift detection: кластер всегда = git.
  History: каждый деплой = git commit.
  Rollback = git revert.
```

## Image Update Automation

Главный вопрос GitOps: как обновить image tag в git при новом build?

### Вариант 1: CI обновляет git напрямую

```yaml
# .github/workflows/ci.yaml
- name: Update image tag in GitOps repo
  run: |
    git clone https://github.com/org/gitops-config.git
    cd gitops-config
    # Обновить tag в kustomization.yaml
    kustomize edit set image myapp=ghcr.io/org/myapp:${{ github.sha }}
    git config user.email "ci@github.com"
    git config user.name "CI Bot"
    git add kustomization.yaml
    git commit -m "Update myapp to ${{ github.sha }}"
    git push
```

### Вариант 2: ArgoCD Image Updater

```yaml
# Аннотации на ArgoCD Application — auto-update image tag
metadata:
  annotations:
    argocd-image-updater.argoproj.io/image-list: myapp=ghcr.io/org/myapp
    argocd-image-updater.argoproj.io/myapp.update-strategy: newest-build
    argocd-image-updater.argoproj.io/write-back-method: git   # пишет в git
    argocd-image-updater.argoproj.io/git-branch: main
```

## Promotion между окружениями

```
feature-branch → PR → code review → merge в main
                                          │
                                  CI: build + push image
                                          │
                                  CI: update gitops/dev/image-tag
                                          │
                                  ArgoCD синхронизирует dev автоматически
                                          │
                                  integration tests pass
                                          │
                                  PR: bump image-tag в gitops/staging/
                                          │
                                  ArgoCD синхронизирует staging
                                          │
                                  staging tests + manual review
                                          │
                                  PR: bump image-tag в gitops/production/
                                  (требует approval от tech lead)
                                          │
                                  ArgoCD синхронизирует production
```

```
gitops-config/
├── base/
│   ├── deployment.yaml
│   └── kustomization.yaml
└── overlays/
    ├── dev/
    │   └── kustomization.yaml    ← image tag автообновляется CI
    ├── staging/
    │   └── kustomization.yaml    ← PR из dev через automation
    └── production/
        └── kustomization.yaml    ← PR из staging, ручной approval
```

## Flux как альтернатива ArgoCD

```bash
# установить Flux CLI
brew install fluxcd/tap/flux

# bootstrap (поднять Flux в кластере из GitHub репо)
flux bootstrap github \
  --owner=org \
  --repository=gitops-config \
  --branch=main \
  --path=./clusters/production \
  --personal
```

```yaml
# Flux GitRepository — источник
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: gitops-config
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/org/gitops-config
  ref:
    branch: main

---
# Flux Kustomization — что применять
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: production-apps
  namespace: flux-system
spec:
  interval: 10m
  path: "./clusters/production"
  prune: true           # удалять ресурсы удалённые из git
  sourceRef:
    kind: GitRepository
    name: gitops-config
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: myapp
      namespace: production
```

## ArgoCD vs Flux

| | ArgoCD | Flux |
|--|--------|------|
| UI | Отличный web UI | Только CLI |
| Архитектура | Centralised | Decentralised (per-cluster) |
| Multi-cluster | Из одного ArgoCD | Отдельный Flux на каждый кластер |
| GitOps паттерн | App-of-Apps, ApplicationSet | Kustomization + HelmRelease |
| Сообщество | Большое, CNCF graduated | Большое, CNCF graduated |
| Кривая обучения | Чуть выше | Чуть ниже |

Оба варианта production-ready. ArgoCD популярнее в Enterprise из-за UI.

## Секреты в GitOps

Главная проблема: секреты нельзя хранить в git.

**Решения:**
1. **Sealed Secrets** (Bitnami) — зашифровать публичным ключом кластера, хранить в git
2. **External Secrets Operator** — ссылки на Vault/AWS SM в git, ESO подтягивает значения
3. **SOPS + age/GPG** — зашифровать файл секретов, хранить в git

```yaml
# External Secrets — хранить только ссылку, не значение
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
spec:
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: db-credentials
  data:
    - secretKey: password
      remoteRef:
        key: secret/production/database
        property: password
# Этот файл безопасно хранить в git — он содержит только путь, не значение
```
