# Tier 2 — Локальный Kubernetes

Для упражнений по k8s нужен работающий кластер. Три варианта по сложности.

## Сравнение инструментов

| | kind | k3d | minikube |
|---|---|---|---|
| Что внутри | k8s в Docker контейнерах | k3s в Docker контейнерах | VM или Docker |
| Скорость старта | ~30 сек | ~15 сек | ~2 мин |
| Ресурсы | минимальные | минимальные | больше (VM) |
| Multi-node | да | да | ограниченно |
| Похож на prod | максимально | близко (k3s) | близко |
| Рекомендован для | тестирования k8s компонентов | быстрых лаб | обучения |

**Рекомендация:** kind для k8s-специфичных упражнений, k3d для быстрых лаб.

## kind (Kubernetes IN Docker)

```bash
# установка
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64
chmod +x kind && sudo mv kind /usr/local/bin/

# одна нода (минимально)
kind create cluster --name lab

# кластер из 3 нод
cat <<EOF | kind create cluster --name lab --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
EOF

# список кластеров
kind get clusters

# переключить kubectl на kind кластер
kubectl cluster-info --context kind-lab

# удалить
kind delete cluster --name lab
```

## k3d (k3s в Docker)

```bash
# установка
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# кластер из 1 control + 2 worker
k3d cluster create lab \
  --servers 1 --agents 2 \
  --port "8080:80@loadbalancer" \
  --wait

# список
k3d cluster list

# остановить / запустить (не удаляет)
k3d cluster stop lab
k3d cluster start lab

# удалить
k3d cluster delete lab
```

## Загрузка локальных образов

```bash
# kind — загрузить локальный образ в кластер (без registry)
docker build -t my-app:dev .
kind load docker-image my-app:dev --name lab

# k3d
k3d image import my-app:dev --cluster lab
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
```

## Полезные инструменты рядом

```bash
# helm — пакетный менеджер k8s
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# k9s — TUI для k8s
# https://k9scli.io/

# kubectx + kubens — быстрое переключение контекстов и namespace
brew install kubectx     # macOS
# Linux: https://github.com/ahmetb/kubectx
```
