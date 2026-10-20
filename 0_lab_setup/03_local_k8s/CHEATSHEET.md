# Локальный Kubernetes — шпаргалка

Подробности и объяснения — в
[local_k8s_options.md](./01_theory/local_k8s_options.md).
⚠️ — опасная команда или частая ловушка.

## Что выбрать

| Задача | Инструмент | Почему |
| :--- | :--- | :--- |
| Большинство упражнений базы | k3d | старт ~15 с, встроенный LoadBalancer и Traefik |
| RBAC, admission, «как в проде» | kind | полный upstream Kubernetes |
| Первое знакомство | minikube | аддоны dashboard / ingress / metrics-server |

| | kind | k3d | minikube |
| :--- | :--- | :--- | :--- |
| Внутри | k8s в Docker | k3s в Docker | VM или Docker |
| RAM | ~300 MB | ~200 MB | 2+ GB |
| LoadBalancer | нет (MetalLB / cloud-provider-kind) | ServiceLB (klipper) | `minikube tunnel` |
| Загрузить локальный образ | `kind load docker-image` | `k3d image import` | `minikube image load` |

## kind

| Задача | Команда |
| :--- | :--- |
| Кластер из одной ноды | `kind create cluster --name lab` |
| Multi-node из конфига | `kind create cluster --name lab --config kind.yaml` |
| Список / удалить ⚠️ | `kind get clusters` / `kind delete cluster --name lab` |
| Образ без registry | `kind load docker-image myapp:dev --name lab` |
| Контекст kubectl | `kind-lab`: `kubectl cluster-info --context kind-lab` |

```yaml
# kind.yaml — 1 control-plane + 2 worker
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
```

## k3d

| Задача | Команда |
| :--- | :--- |
| 1 server + 2 agents + порты LB | `k3d cluster create lab --servers 1 --agents 2 --port "8080:80@loadbalancer" --wait` |
| Список | `k3d cluster list` |
| Остановить / запустить (без удаления) | `k3d cluster stop lab` / `k3d cluster start lab` |
| Удалить ⚠️ | `k3d cluster delete lab` |
| Образ без registry | `k3d image import myapp:dev --cluster lab` |
| Контекст kubectl | `k3d-lab` |

## minikube

| Задача | Команда |
| :--- | :--- |
| Старт на Docker-драйвере | `minikube start --driver=docker --cpus=4 --memory=8g` |
| Аддоны | `minikube addons enable ingress` (`metrics-server`, `dashboard`) |
| Список аддонов | `minikube addons list` |
| Статус / стоп / удалить ⚠️ | `minikube status` / `minikube stop` / `minikube delete` |
| IP ноды для NodePort | `minikube ip` |
| LoadBalancer-сервисам — внешний IP | `minikube tunnel` (держать открытым) |
| Dashboard | `minikube dashboard` |
| Контекст kubectl | `minikube` |

## kubectl и соседи

| Задача | Команда |
| :--- | :--- |
| Версия клиента | `kubectl version --client` |
| Текущий / все контексты | `kubectl config current-context` / `kubectl config get-contexts` |
| Переключить контекст | `kubectl config use-context kind-lab` |
| Автодополнение | `source <(kubectl completion bash)` (или `zsh`) |
| Алиас с дополнением (bash) | `alias k=kubectl`<br>`complete -o default -F __start_kubectl k` |
| TUI | `k9s` |
| Контексты / namespace | `kubectx` / `kubens` |
| Логи многих подов | `stern <pod-prefix>` |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| `ErrImagePull` у своего образа | образ не загружен в кластер: `kind load` / `k3d image import` |
| `EXTERNAL-IP <pending>` у LoadBalancer | в kind нет LB; в minikube не запущен `tunnel` |
| kubectl ходит не в тот кластер ⚠️ | `kubectl config current-context`, явный `--context` |
| kind не стартует, `too many open files` | лимиты inotify хоста: `sysctl fs.inotify.max_user_instances` |
| minikube «съел» всю RAM | уменьшить `--memory` или перейти на k3d/kind |

> Проверка: флаги сверены с `--help` у kind v0.30.0, k3d v5.8.3,
> minikube v1.39.0 и kubectl (бинарники в scratch, кластеры не
> создавались); не проверено: `k9s`, `kubectx`, `stern`.
