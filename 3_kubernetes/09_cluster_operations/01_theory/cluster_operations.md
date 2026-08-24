# Cluster Operations — эксплуатация кластера

## Troubleshooting — диагностика проблем

### Pod не запускается

```bash
kubectl get pods -n mynamespace
kubectl describe pod mypod -n mynamespace    # смотреть Events секцию
kubectl logs mypod -n mynamespace            # логи контейнера
kubectl logs mypod -n mynamespace --previous # логи предыдущего контейнера (если рестартовал)
kubectl logs mypod -n mynamespace -c mycontainer  # конкретный контейнер

# Частые причины по Events:
# ImagePullBackOff    → неверный образ/тег или нет доступа к registry
# OOMKilled           → контейнер превысил memory limit
# CrashLoopBackOff    → приложение падает, k8s перезапускает с задержкой
# Pending             → нет подходящей ноды (ресурсы, selector, taints)
# ContainerCreating   → проблема с монтированием volume или network
```

```bash
# Типичная диагностика CrashLoopBackOff
kubectl describe pod mypod | grep -A 10 "Last State"
kubectl logs mypod --previous

# Запустить shell вместо приложения (если образ содержит shell)
kubectl run debug --image=myapp:latest --restart=Never \
  --command -- sleep 3600
kubectl exec -it debug -- sh

# Или использовать ephemeral container (k8s 1.23+)
kubectl debug mypod -it --image=busybox --target=mycontainer
```

### Pod в Pending

```bash
kubectl describe pod mypod | grep -A 5 "Events:"
# Смотреть: "0/3 nodes are available: 3 Insufficient memory"
# или: "didn't match Pod's node affinity/selector"
# или: "had taint ... that the pod didn't tolerate"

# Проверить доступные ресурсы на нодах
kubectl describe nodes | grep -A 5 "Allocated resources:"
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.allocatable.cpu,MEM:.status.allocatable.memory
```

### Проблемы с сетью

```bash
# Проверить endpoints сервиса (есть ли поды)
kubectl get endpoints myservice
# Если пусто: podSelector в Service не совпадает с labels Pod

# Проверить DNS из пода
kubectl exec -it mypod -- nslookup myservice.mynamespace.svc.cluster.local

# Проверить NetworkPolicy (может блокировать трафик)
kubectl get networkpolicy -n mynamespace

# tcpdump на ноде
node_ip=$(kubectl get pod mypod -o jsonpath='{.status.hostIP}')
ssh $node_ip "tcpdump -i any -n port 8080 -w /tmp/cap.pcap"
```

## Node Drain и обслуживание

```bash
# Обслуживание ноды: запретить новые поды + выселить существующие
kubectl cordon worker-1                           # шаг 1: запретить новые поды
kubectl drain worker-1 \                          # шаг 2: выселить
  --ignore-daemonsets \                           # DaemonSet поды не трогать
  --delete-emptydir-data \                        # удалить поды с emptyDir
  --grace-period=60 \                             # дать 60с на graceful shutdown
  --timeout=300s                                  # максимум 5 мин на drain

# Провести обслуживание...

kubectl uncordon worker-1                         # вернуть в строй
```

## Обновление кластера (kubeadm)

```bash
# 1. Обновить control plane
# НА CONTROL PLANE НОДЕ:
apt-get update && apt-get install -y kubeadm=1.29.0-00
kubeadm upgrade plan                              # посмотреть доступные версии
kubeadm upgrade apply v1.29.0                     # обновить control plane компоненты

apt-get install -y kubelet=1.29.0-00 kubectl=1.29.0-00
systemctl daemon-reload && systemctl restart kubelet

# 2. Обновить worker ноды (по одной)
# НА CONTROL PLANE:
kubectl drain worker-1 --ignore-daemonsets --delete-emptydir-data

# НА WORKER НОДЕ:
apt-get install -y kubeadm=1.29.0-00
kubeadm upgrade node
apt-get install -y kubelet=1.29.0-00
systemctl daemon-reload && systemctl restart kubelet

# НА CONTROL PLANE:
kubectl uncordon worker-1
```

## etcd backup и восстановление

```bash
# Backup (выполнять регулярно, хранить offsite)
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-$(date +%Y%m%d-%H%M%S).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key

# Проверить snapshot
ETCDCTL_API=3 etcdctl snapshot status /backup/etcd-20240115-120000.db \
  --write-out=table

# Восстановление (только при полной потере etcd)
# 1. Остановить control plane компоненты
systemctl stop kubelet

# 2. Восстановить данные
ETCDCTL_API=3 etcdctl snapshot restore /backup/etcd-20240115-120000.db \
  --data-dir=/var/lib/etcd-restore \
  --initial-cluster=master=https://10.0.0.1:2380 \
  --initial-advertise-peer-urls=https://10.0.0.1:2380 \
  --name=master

# 3. Заменить data dir и запустить
mv /var/lib/etcd /var/lib/etcd-broken
mv /var/lib/etcd-restore /var/lib/etcd
systemctl start kubelet
```

## Полезные команды для ежедневной работы

```bash
# Ресурсы всего кластера
kubectl top nodes
kubectl top pods --all-namespaces --sort-by=memory

# Найти pod по любому критерию
kubectl get pods -A -o wide | grep worker-1        # поды на конкретной ноде
kubectl get pods -A --field-selector status.phase=Failed
kubectl get pods -A | grep -E "CrashLoop|Error|OOMKilled"

# Быстрый рестарт деплоя (без изменения конфигурации)
kubectl rollout restart deployment/myapp -n production

# Форсировать удаление застрявшего пода
kubectl delete pod mypod --grace-period=0 --force

# Посмотреть все события в namespace
kubectl get events -n production --sort-by='.lastTimestamp'
kubectl get events -n production --field-selector reason=OOMKilling

# Очистить завершённые и упавшие поды
kubectl delete pods -A --field-selector status.phase=Succeeded
kubectl delete pods -A --field-selector status.phase=Failed
```
