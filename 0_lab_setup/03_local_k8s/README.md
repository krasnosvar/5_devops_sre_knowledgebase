# 03. Локальный Kubernetes

## Зачем

Для упражнений по Kubernetes нужен работающий кластер, а облачный
managed-кластер стоит денег и долго создаётся. kind/k3d/minikube поднимают
кластер локально за десятки секунд поверх Docker (🐳 Tier 1); полная
установка через kubeadm на VM — это уже 🖥 Tier 2 (см.
[02_local_vms](../02_local_vms/)).

## Пререквизиты

- [01_docker_compose](../01_docker_compose/) — Docker установлен и
  работает.

> **Забегание вперёд.** Здесь используется kubectl, который подробно
> разбирается в [4_kubernetes](../../4_kubernetes/). Для этой темы
> достаточно: `kubectl cluster-info`, `kubectl get nodes`,
> `kubectl get pods -A`. Если Kubernetes ещё не освоен — тему можно
> отложить до начала раздела 4.

## Файлы

- [01_theory/local_k8s_options.md](01_theory/local_k8s_options.md) —
  сравнение kind / k3d / minikube, установка, загрузка образов, kubectl.
- [02_examples/kind-cluster.yaml](02_examples/kind-cluster.yaml) — kind:
  1 control-plane + 2 workers, проброс 80/443 на 8080/8443 хоста.
- Без `03_exercises/`: тема — только про подъём кластера, упражнения на
  сам Kubernetes — в [4_kubernetes](../../4_kubernetes/).

## Как проходить

1. Прочитать теорию и выбрать инструмент.
2. Создать кластер из `kind-cluster.yaml`, проверить `kubectl get nodes`.
3. Загрузить локальный образ (`kind load docker-image`) и удалить кластер.

## Сравнение инструментов

Три варианта по сложности.

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

## Когда двигаться дальше

- Можете создать и удалить кластер из конфига `kind-cluster.yaml`.
- Можете загрузить локально собранный образ в kind/k3d без registry.
- Понимаете, когда хватит kind, а когда нужен kubeadm на VM.
- Дальше — [04_cloud_vps](../04_cloud_vps/).
