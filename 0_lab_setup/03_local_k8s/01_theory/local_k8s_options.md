# Локальный Kubernetes — выбор инструмента

## Сравнение: kind vs k3d vs minikube

| | kind | k3d | minikube |
|---|---|---|---|
| Что внутри | full k8s в Docker | k3s в Docker | VM или Docker |
| Старт кластера | ~30 сек | ~15 сек | ~2 мин |
| Ресурсы | ~300 MB RAM | ~200 MB RAM | 2+ GB RAM |
| Multi-node | ✅ | ✅ | ограниченно |
| Близость к prod | Максимально | Близко (k3s ≈ k8s) | Близко |
| LoadBalancer | нет (нужен MetalLB) | встроен (traefik) | встроен |
| Загрузка образов | `kind load` | `k3d image import` | `minikube image load` |
| CRI | containerd | containerd | containerd / docker |
| Рекомендован для | тестирование k8s компонентов | быстрые лабы | обучение |

## kind — Kubernetes IN Docker

Каждый node кластера = Docker контейнер. Полноценный k8s API.
Лучший выбор для тестирования k8s-специфичного поведения (RBAC, admission controllers).

```bash
# установка
curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64"
chmod +x kind && sudo mv kind /usr/local/bin/

# одна нода
kind create cluster --name lab

# multi-node кластер
cat <<EOF | kind create cluster --name lab --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
EOF

# управление
kind get clusters
kind delete cluster --name lab

# kubeconfig
kubectl cluster-info --context kind-lab
```

## k3d — k3s в Docker

k3s — lightweight Kubernetes от Rancher (CNCF). k3d запускает k3s в Docker.
Встроенный Traefik LoadBalancer — удобен для упражнений с Ingress.

```bash
# установка
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# кластер с 1 control-plane + 2 workers + port mapping
k3d cluster create lab \
  --servers 1 \
  --agents 2 \
  --port "8080:80@loadbalancer" \
  --port "8443:443@loadbalancer" \
  --wait

# управление
k3d cluster list
k3d cluster stop lab    # остановить (не удалять)
k3d cluster start lab   # запустить снова
k3d cluster delete lab

# загрузить локальный образ без registry
docker build -t myapp:dev .
k3d image import myapp:dev --cluster lab
```

## minikube

Классический инструмент для обучения. Поднимает одну или несколько нод.
Встроенные аддоны: dashboard, ingress, metrics-server.

```bash
# установка
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
chmod +x minikube && sudo mv minikube /usr/local/bin/

# запустить (Docker driver — рекомендуется)
minikube start --driver=docker --cpus=4 --memory=8g

# включить полезные аддоны
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable dashboard

# управление
minikube status
minikube stop
minikube delete

# открыть dashboard
minikube dashboard

# получить IP для доступа к NodePort сервисам
minikube ip
```

## Установка kubectl

```bash
# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# macOS
brew install kubectl

# проверить
kubectl version --client

# автодополнение (добавить в .zshrc или .bashrc)
source <(kubectl completion bash)   # bash
source <(kubectl completion zsh)    # zsh
alias k=kubectl
complete -F __start_kubectl k
```

## Инструменты рядом

```bash
# Helm — пакетный менеджер k8s
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# k9s — TUI для k8s (очень удобен)
# https://k9scli.io/topics/install/
brew install k9s   # macOS
# или: скачать бинарник с GitHub releases

# kubectx + kubens — переключение контекстов и namespace
brew install kubectx

# stern — tail логов нескольких pod одновременно
brew install stern

# kustomize (standalone)
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
sudo mv kustomize /usr/local/bin/
```

## Рекомендация для упражнений базы

- **Большинство упражнений** → `k3d` (быстрее стартует, встроенный LB)
- **RBAC и security упражнения** → `kind` (полный k8s API)
- **Первое знакомство с k8s** → `minikube` (dashboard, аддоны из коробки)
