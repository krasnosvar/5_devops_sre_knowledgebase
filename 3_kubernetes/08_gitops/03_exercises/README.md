# Упражнения — GitOps / ArgoCD

Стенд: 🐳 Tier 1 — kind + ArgoCD

```bash
# Поднять kind кластер
kind create cluster --name lab

# Установить ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server

# Получить пароль
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Port-forward UI
kubectl -n argocd port-forward svc/argocd-server 8080:443 &
```

## 01 — Первое приложение в ArgoCD

**Задача:** Создать ArgoCD Application из публичного GitHub репозитория. Изменить что-то в репозитории (fork). Убедиться что ArgoCD автоматически синхронизирует изменения.

```bash
# TODO: написать application.yaml
kubectl apply -f application.yaml
argocd app sync myapp
argocd app get myapp
```

## 02 — Kustomize overlays

**Задача:** Создать base Deployment + два overlay (dev, prod) с разными replica count и resource limits. Задеплоить оба через ArgoCD.

Структура:
```
manifests/
├── base/
│   ├── deployment.yaml
│   └── kustomization.yaml
└── overlays/
    ├── dev/
    │   └── kustomization.yaml   # 1 replica
    └── prod/
        └── kustomization.yaml   # 3 replicas + resource limits
```

## 03 — Self-heal и drift detection

**Задача:** Включить selfHeal в ArgoCD Application. Вручную изменить Deployment (kubectl scale). Убедиться что ArgoCD автоматически восстанавливает желаемое состояние.

## 04 — ApplicationSet

**Задача:** Создать ApplicationSet который генерирует Application для каждого overlay в директории (generator: git directories).
