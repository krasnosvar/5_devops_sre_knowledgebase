# Сеть контейнеров

## Docker сетевые режимы

**bridge** (default) — контейнер получает veth pair, подключённый к `docker0` bridge.
Изолирован от хоста, выходит наружу через NAT (MASQUERADE iptables).

**host** — контейнер использует сетевой namespace хоста напрямую.
Нет NAT, нет изоляции. Максимальная производительность сети.
```bash
docker run --network=host nginx   # nginx слушает на портах хоста напрямую
```

**none** — нет сетевых интерфейсов кроме loopback. Полная изоляция.

**overlay** — для Docker Swarm: сеть поверх физической, между узлами кластера.

## bridge сеть изнутри

```
Хост                                  Контейнер
─────                                 ─────────
docker0 (172.17.0.1)                  eth0 (172.17.0.2)
    │                                     │
    └──── veth pair ──────────────────────┘
    
iptables:
  MASQUERADE: 172.17.0.0/16 → eth0 (NAT для исходящего трафика)
  DNAT:       <host-port> → 172.17.0.2:<container-port>
```

```bash
# посмотреть docker сети
docker network ls
docker network inspect bridge

# создать пользовательскую bridge сеть
docker network create --subnet 172.20.0.0/16 mynet

# контейнеры в одной пользовательской сети находят друг друга по имени
docker run -d --name db --network mynet postgres
docker run -d --name app --network mynet myapp
# app может делать: psql -h db ...
```

## DNS в Docker

В default bridge: DNS через `/etc/resolv.conf` хоста. Имена контейнеров не резолвятся.
В user-defined bridge: встроенный DNS сервер Docker (127.0.0.11). Контейнеры
резолвят друг друга по имени сервиса.

```bash
# внутри контейнера в user-defined bridge
cat /etc/resolv.conf
# nameserver 127.0.0.11
# options ndots:0

# резолвинг по имени сервиса
ping db              # резолвится в IP контейнера db
nslookup app 127.0.0.11
```

## Port mapping — как работает DNAT

```bash
docker run -p 8080:80 nginx
# Создаёт правило iptables:
# -A DOCKER -p tcp --dport 8080 -j DNAT --to-destination 172.17.0.2:80
# -A POSTROUTING -s 172.17.0.2/32 -d 172.17.0.2/32 -p tcp --dport 80 -j MASQUERADE
```

## Сеть в Kubernetes — CNI

CNI (Container Network Interface) — стандарт для плагинов сети k8s.
При создании Pod, kubelet вызывает CNI плагин который:
1. Создаёт veth pair
2. Подключает один конец к Pod network namespace
3. Подключает другой к node bridge или routing
4. Назначает IP из Pod CIDR

### Популярные CNI плагины

| CNI | Особенности |
|-----|-------------|
| **Flannel** | Простой, VXLAN overlay, нет NetworkPolicy |
| **Calico** | BGP routing (без overlay), NetworkPolicy, мощный |
| **Cilium** | eBPF, L7 NetworkPolicy, без iptables, лучшая производительность |
| **Weave** | Mesh networking, NetworkPolicy |

### Pod networking — фундаментальные правила

1. Каждый Pod получает уникальный IP в кластере
2. Pod видит все другие Pod'ы напрямую (без NAT) по их IP
3. Node видит все Pod'ы на всех Node'ах
4. Pod видит свой собственный IP так же как видят его другие

## Kubernetes Services — стабильный IP для группы Pod'ов

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  selector:
    app: myapp          # выбирает Pod'ы с этим label
  ports:
    - port: 80          # порт Service
      targetPort: 8080  # порт Pod'а
  type: ClusterIP       # только внутри кластера
```

**ClusterIP** — виртуальный IP внутри кластера. kube-proxy создаёт iptables/IPVS правила.
**NodePort** — дополнительно открывает порт на каждой ноде (30000-32767).
**LoadBalancer** — запрашивает внешний LB у cloud provider.
**Headless** (ClusterIP: None) — нет виртуального IP, DNS возвращает IP Pod'ов напрямую. Используется для StatefulSet.

## kube-proxy и iptables

```bash
# правила kube-proxy (iptables режим)
iptables -t nat -L KUBE-SERVICES -n
iptables -t nat -L KUBE-SVC-<hash> -n    # правила для конкретного Service

# kube-proxy в IPVS режиме (лучше при >1000 Services)
ipvsadm -ln
ipvsadm -ln | grep <ClusterIP>
```

## CoreDNS — DNS в k8s

```bash
# DNS имена в k8s
my-service.my-namespace.svc.cluster.local   # полное имя
my-service.my-namespace                     # в другом namespace
my-service                                  # в том же namespace

# проверка DNS из pod
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- bash
nslookup kubernetes.default.svc.cluster.local
dig @10.96.0.10 my-service.default.svc.cluster.local   # 10.96.0.10 = CoreDNS IP
```
