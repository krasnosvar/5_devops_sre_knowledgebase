# Архитектура Kubernetes

## Control Plane vs Data Plane

```
┌──────────────────────────────────────────────────────┐
│                   CONTROL PLANE                      │
│                                                      │
│  kube-apiserver  ←──── единственная точка входа     │
│       │                                              │
│  etcd ┘  (state)    kube-scheduler                  │
│                      kube-controller-manager         │
│                      cloud-controller-manager        │
└──────────────────────────────────────────────────────┘
           │ watches & updates
┌──────────────────────────────────────────────────────┐
│                    DATA PLANE (Nodes)                │
│                                                      │
│  kubelet ──► containerd ──► runc ──► containers     │
│  kube-proxy (iptables/IPVS rules for Services)       │
│  CNI plugin (network for Pods)                       │
└──────────────────────────────────────────────────────┘
```

## kube-apiserver

Единственная точка доступа к кластеру. Все компоненты (включая kubectl) общаются
только через API server.

- RESTful API поверх HTTPS
- Аутентификация (сертификаты, ServiceAccount tokens, OIDC)
- Авторизация (RBAC)
- Admission controllers (валидация и мутация объектов)
- Хранит состояние в etcd

```bash
# прямой запрос к API
kubectl proxy &              # запустить прокси на localhost:8001
curl http://localhost:8001/api/v1/pods

# или через kubectl
kubectl get --raw /api/v1/pods | jq .
kubectl api-resources         # все доступные типы объектов
kubectl api-versions          # все версии API
```

## etcd

Распределённое key-value хранилище (Raft консенсус). Хранит полное состояние
кластера. **Единственная stateful компонента control plane.**

```bash
# бэкап (критически важно!)
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-$(date +%Y%m%d).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# восстановление
ETCDCTL_API=3 etcdctl snapshot restore /backup/etcd-20240101.db \
  --data-dir=/var/lib/etcd-restore

# размер etcd (растёт со временем, нужна дефрагментация)
ETCDCTL_API=3 etcdctl endpoint status --write-out=table
ETCDCTL_API=3 etcdctl defrag
```

## kube-scheduler

Выбирает на какую ноду разместить Pod:

1. **Filtering** — исключить ноды которые не подходят (недостаточно ресурсов,
   taints, nodeSelector)
2. **Scoring** — оценить оставшиеся ноды (spread, resource balance, affinity)
3. Выбрать ноду с максимальным score → записать `spec.nodeName` в Pod

```bash
# посмотреть почему Pod pending
kubectl describe pod mypod    # Events секция покажет причину
kubectl get events --field-selector reason=FailedScheduling
```

## kube-controller-manager

Набор control loops (контроллеров). Каждый контроллер следит за своим типом
объектов и приводит текущее состояние к желаемому.

**Reconciliation loop** — фундаментальный паттерн k8s:
```
watch API server → текущее состояние != желаемое? → act → watch...
```

Примеры контроллеров:
- `ReplicaSet controller` — следит за количеством Pod
- `Deployment controller` — управляет rolling update
- `Node controller` — помечает ноды NotReady при недоступности
- `Job controller` — запускает Pod до успешного завершения

## kubelet

Агент на каждой ноде. Берёт Pod spec из API server и создаёт контейнеры.

```bash
# статус kubelet
systemctl status kubelet
journalctl -u kubelet -f       # логи

# конфигурация
cat /var/lib/kubelet/config.yaml
cat /etc/kubernetes/kubelet.conf  # kubeconfig для общения с API server
```

## Что происходит при `kubectl apply -f deployment.yaml`

1. `kubectl` → POST /apis/apps/v1/namespaces/default/deployments → API server
2. API server: аутентификация → авторизация → admission controllers → etcd
3. Deployment controller видит новый Deployment → создаёт ReplicaSet
4. ReplicaSet controller видит новый RS → создаёт N Pod объектов
5. kube-scheduler видит Pod без `spec.nodeName` → выбирает ноду → патчит Pod
6. kubelet на выбранной ноде видит Pod назначенный ему → вызывает containerd
7. containerd через CNI настраивает сеть → через runc запускает контейнеры
8. kubelet обновляет `status` Pod в API server
