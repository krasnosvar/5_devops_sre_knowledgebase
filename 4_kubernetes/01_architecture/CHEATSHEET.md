# Архитектура Kubernetes — шпаргалка

Подробности и объяснения — в
[k8s_architecture.md](./01_theory/k8s_architecture.md). ⚠️ — опасная
команда или частая ловушка.

## Компоненты: кто что делает

| Компонент | Роль | Где живёт (kubeadm) |
| :--- | :--- | :--- |
| kube-apiserver | единственная дверь в кластер, единственный, кто пишет в etcd | Static Pod |
| etcd | KV-хранилище состояния, Raft + MVCC | Static Pod |
| kube-scheduler | назначает `spec.nodeName` подам без ноды | Static Pod |
| kube-controller-manager | десятки control loops (watch → diff → act) | Static Pod |
| cloud-controller-manager | LB для `type: LoadBalancer`, маршруты, ноды облака | Deployment/облако |
| kubelet | запускает поды своей ноды через CRI, пробы, eviction | systemd-юнит |
| container runtime | containerd / CRI-O | systemd-юнит |
| kube-proxy | правила Service (iptables/IPVS/nftables) | DaemonSet |

| Ресурс | Контроллер |
| :--- | :--- |
| Deployment → ReplicaSet | deployment controller (ReplicaSet, не поды) |
| ReplicaSet → Pod | replicaset controller |
| StatefulSet → Pod + PVC | statefulset controller (без ReplicaSet) |
| DaemonSet | daemonset controller |
| Job / CronJob | job controller / cronjob controller |
| Node `NotReady`, taints | node lifecycle controller |
| EndpointSlice | endpointslice controller |
| CRD | свой оператор (controller-runtime), не KCM |

## Путь запроса в kube-apiserver

| Фаза | Что происходит |
| :--- | :--- |
| 1. Authentication | X.509, OIDC, токены ServiceAccount |
| 2. Authorization | обычно RBAC |
| 3. Mutating admission | вебхуки дописывают объект (sidecar, дефолты) |
| 4. Schema validation | объект проверяется по схеме |
| 5. Validating admission | вебхуки/политики могут отклонить |
| 6. Запись в etcd | после этого watch разошлёт событие |

## Control plane: посмотреть состояние

| Задача | Команда |
| :--- | :--- |
| Поды control plane (self-hosted) | `kubectl get pods -n kube-system -o wide` |
| Логи компонента | `kubectl logs -n kube-system kube-controller-manager-<node>` |
| Кто лидер KCM / scheduler | `kubectl get lease -n kube-system kube-controller-manager -o jsonpath='{.spec.holderIdentity}'` |
| Готовность API-сервера | `kubectl get --raw='/readyz?verbose'` |
| Liveness API-сервера | `kubectl get --raw='/livez'` |
| Действия контроллера над объектом | `kubectl describe rs <name>` → Events (`SuccessfulCreate`) |
| События одного объекта | `kubectl events --for deployment/web` |
| Итог решения контроллера | `kubectl get deploy web -o jsonpath='{.status.conditions}'` |
| Манифесты Static Pods | `ls /etc/kubernetes/manifests/` (на control-plane ноде) |
| Heartbeat-объекты нод | `kubectl get lease -n kube-node-lease` |

## Нода и kubelet

| Задача | Команда |
| :--- | :--- |
| Логи kubelet | `journalctl -u kubelet -f --since "10 min ago"` |
| Состояние kubelet | `systemctl status kubelet` |
| Поды и контейнеры через CRI | `crictl pods`, `crictl ps -a` |
| Логи / inspect контейнера | `crictl logs <id>`, `crictl inspect <id>` |
| Образы на ноде | `crictl images` |
| Shell на ноде без SSH ⚠️ привилегии хоста | `kubectl debug node/<node> -it --image=busybox` (хост в `/host`) |
| Условия и ёмкость ноды | `kubectl describe node <node>` (Conditions, Allocatable) |

## etcd

| Задача | Команда |
| :--- | :--- |
| Общие флаги (kubeadm) | `--endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key` |
| Члены кластера | `etcdctl member list -w table` |
| Здоровье / лидер / размер БД | `etcdctl endpoint health --cluster`<br>`etcdctl endpoint status --cluster -w table` |
| Снапшот | `etcdctl snapshot save /backup/etcd-$(date +%F).db` |
| Проверить снапшот | `etcdutl snapshot status /backup/etcd.db -w table` |
| Восстановить ⚠️ в новый data-dir | `etcdutl snapshot restore /backup/etcd.db --data-dir /var/lib/etcd-restore` |
| Compaction до текущей ревизии | `etcdctl compact <rev>` (rev из `endpoint status -w json`) |
| Дефрагментация ⚠️ блокирует член на время | `etcdctl defrag --endpoints=<one-member>` |
| Снять alarm NOSPACE | `etcdctl alarm list`, после defrag `etcdctl alarm disarm` |

| Узлов etcd | Кворум | Переживёт отказ |
| :--- | :--- | :--- |
| 1 | 1 | 0 |
| 3 | 2 | 1 |
| 4 | 3 | 1 (4-й узел бесполезен) |
| 5 | 3 | 2 |

## Типовые значения

| Параметр | По умолчанию |
| :--- | :--- |
| `node-status-update-frequency` kubelet | 10s |
| Generic PLEG relist | раз в 1s; `PLEG is not healthy` — relist дольше 3 мин |
| Taint `not-ready`/`unreachable` toleration | `tolerationSeconds: 300` |
| `revisionHistoryLimit` Deployment | 10 |
| etcd `--quota-backend-bytes` | 2 GiB (рекомендуемый максимум 8 GiB) |
| Порты: apiserver / etcd / kubelet | 6443 / 2379-2380 / 10250 |

## Подъём кластера

| Способ | Когда |
| :--- | :--- |
| kubeadm | ручной self-hosted, база для остальных |
| Managed (EKS/GKE/AKS) | прод по умолчанию: control plane у облака |
| Kops | self-hosted в облаке, инфраструктура из Terraform |
| Kubespray | bare-metal/on-prem, Ansible поверх kubeadm |

| Задача | Команда |
| :--- | :--- |
| Поднять первую control-plane ноду | `kubeadm init --pod-network-cidr=10.244.0.0/16` |
| Команда присоединения ноды | `kubeadm token create --print-join-command` |
| Срок сертификатов | `kubeadm certs check-expiration` |
| План обновления | `kubeadm upgrade plan` |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| Под `Pending` | scheduler: `describe pod` → `FailedScheduling` |
| Нода `NotReady` | `journalctl -u kubelet`, `PLEG is not healthy`, containerd, iowait |
| `kubectl` висит/таймаут | `/readyz`, etcd health, сертификаты apiserver |
| etcd `mvcc: database space exceeded` | compaction + defrag + `alarm disarm` |
| Deployment не создаёт поды | Events ReplicaSet, admission-отказы, ResourceQuota |
| На managed-кластере нет подов control plane | так и задумано: смотрите Events и status |

## Ловушки

- ⚠️ Чётное число узлов etcd не добавляет отказоустойчивости.
- ⚠️ Compaction не уменьшает файл БД — место на диске вернёт только defrag.
- Упал control plane — приложения работают, но никто ничего не пересоздаст.
- KCM в HA работает Active-Passive через Lease, не Active-Active.

> Проверка: kubectl-команды сверены с `--help` (v1.34.1) и прогнаны на
> временном kind-кластере (lease, `--raw /readyz`, `events --for`);
> не проверено: `etcdctl`/`etcdutl`, `crictl`, `kubeadm` (по документации
> etcd v3.5+/kubeadm, локально не запускались).
