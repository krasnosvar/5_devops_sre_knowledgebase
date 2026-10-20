# Сети в Kubernetes — шпаргалка

Подробности и объяснения — в [01_theory/](./01_theory/). ⚠️ — опасная
команда или частая ловушка.

## Типы Service и вход в кластер

Подробно: [01_k8s_networking.md](./01_theory/01_k8s_networking.md),
[02_k8s_networking_flow.md](./01_theory/02_k8s_networking_flow.md) §8–11.

| Тип | Что даёт | Когда |
| :--- | :--- | :--- |
| `ClusterIP` (по умолчанию) | виртуальный IP внутри кластера | East-West между сервисами |
| headless (`clusterIP: None`) | DNS отдаёт IP подов, без балансировки | StatefulSet, клиентская балансировка |
| `NodePort` | порт 30000–32767 на всех нодах | отладка, за внешним LB ⚠️ открыт на каждой ноде |
| `LoadBalancer` | облачный LB → NodePort | вход L4; on-prem нужен MetalLB |
| `ExternalName` | CNAME на внешнее имя | алиас внешнего сервиса |
| Ingress / Gateway API | L7: host, path, TLS | HTTP(S)-вход по одному IP |

| `externalTrafficPolicy` | Client IP | Хоп между нодами | Минус |
| :--- | :--- | :--- | :--- |
| `Cluster` (по умолчанию) | теряется (SNAT) | возможен | лишний хоп |
| `Local` | сохраняется | нет | перекос нагрузки; ноды без пода не проходят health check LB |

| Ingress | Gateway API |
| :--- | :--- |
| один объект, логика в аннотациях контроллера | роли: `GatewayClass` → `Gateway` (админ) → `HTTPRoute` (команда) |
| только HTTP(S) | HTTP, gRPC, TCP/UDP/TLS-маршруты |
| ⚠️ ingress-nginx (kubernetes/ingress-nginx) снят с поддержки в 2026 | новый вход строят на Gateway API |

## Команды: Service, DNS, связность

| Задача | Команда |
| :--- | :--- |
| Service и его selector | `kubectl get svc web -o wide` |
| Какие поды за Service (готовые/нет) | `kubectl get endpointslices -l kubernetes.io/service-name=web -o wide` |
| Создать Service для Deployment | `kubectl expose deployment web --port=80 --target-port=8080` |
| Сменить тип | `kubectl patch svc web -p '{"spec":{"type":"NodePort"}}'` |
| Одноразовый под для проверок | `kubectl run net --rm -it --image=nicolaka/netshoot -- bash` |
| Резолв изнутри пода | `kubectl exec -it net -- nslookup web.default.svc.cluster.local` |
| resolv.conf пода | `kubectl exec <pod> -- cat /etc/resolv.conf` |
| HTTP до Service из кластера | `kubectl run curl --rm -it --image=curlimages/curl -- curl -sv http://web` |
| Эфемерный debug-контейнер в под без shell | `kubectl debug -it <pod> --image=nicolaka/netshoot --target=<container>` |
| Логи CoreDNS | `kubectl logs -n kube-system -l k8s-app=kube-dns` |
| Конфиг CoreDNS | `kubectl get cm coredns -n kube-system -o yaml` |
| Режим kube-proxy | `kubectl get cm kube-proxy -n kube-system -o yaml \| grep mode` |
| Ingress и адрес | `kubectl get ingress -A`; `kubectl describe ingress web` |
| Gateway API | `kubectl get gatewayclass,gateway,httproute -A` |

## На ноде: путь пакета

| Задача | Команда |
| :--- | :--- |
| Цепочки Service (iptables-режим) | `iptables -t nat -L KUBE-SERVICES -n \| grep <ClusterIP>` |
| Правила конкретного Service | `iptables-save -t nat \| grep KUBE-SVC-` |
| nftables-режим kube-proxy | `nft list table ip kube-proxy` |
| IPVS-режим | `ipvsadm -Ln` |
| conntrack-запись соединения | `conntrack -L -d <ClusterIP>` |
| Переполнение conntrack | `conntrack -S` (`insert_failed`, `drop`); `sysctl net.netfilter.nf_conntrack_max` |
| veth и маршруты к подам | `ip -br link`, `ip route` |
| netns пода по PID | `nsenter -t <pid> -n ip addr` (PID: `crictl inspect <id>`) |
| Трафик пода на хосте | `tcpdump -ni <vethXXX>` |
| VXLAN-трафик между нодами | `tcpdump -ni eth0 udp port 4789` (Flannel: 8472) |
| MTU пода | `kubectl exec <pod> -- cat /sys/class/net/eth0/mtu` |
| Проверить MTU без фрагментации | `ping -M do -s 1422 <podIP>` (1450 − 28) |

| Режим kube-proxy | Поиск правила | Статус |
| :--- | :--- | :--- |
| `iptables` | O(N), полный `iptables-restore` | по умолчанию в Linux |
| `nftables` | map-структуры, инкрементальные обновления | GA с 1.33 |
| `ipvs` | хэш-таблицы, алгоритмы LB | deprecated с 1.35 |
| eBPF (Cilium KPR) | BPF-maps, DNAT на `connect()` (`cgroup/connect4`) | без kube-proxy |

## CNI: overlay или routing

| Режим | Плюсы | Минусы | Пример |
| :--- | :--- | :--- | :--- |
| Overlay VXLAN | работает поверх любой L3-сети | ~50 байт заголовка → MTU 1450, CPU на инкапсуляцию | Flannel, Calico VXLAN |
| Direct routing / BGP | line-rate, без потерь MTU | сеть должна знать `podCIDR` (BGP с ToR) | Calico BGP, Cilium native |
| eBPF | без iptables, быстрый NetworkPolicy | нужно свежее ядро | Cilium |

## NetworkPolicy

```yaml
# default deny: ingress и egress для всех подов namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: default-deny-all, namespace: app}
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
---
# после default deny разрешить DNS
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-dns, namespace: app}
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - to:
        - namespaceSelector:
            matchLabels: {kubernetes.io/metadata.name: kube-system}
          podSelector:
            matchLabels: {k8s-app: kube-dns}
      ports: [{port: 53, protocol: UDP}, {port: 53, protocol: TCP}]
```

| Пишете | Значит |
| :--- | :--- |
| `- namespaceSelector: …` и `podSelector: …` в ОДНОМ элементе `from` | И (поды с меткой в этих namespace) |
| два отдельных элемента `- namespaceSelector` / `- podSelector` | ИЛИ |
| `policyTypes: [Ingress]` без `Egress` | исходящий трафик открыт |

## Service Mesh, ExternalDNS, cert-manager, MetalLB

| Задача | Команда / поле |
| :--- | :--- |
| Включить sidecar-инъекцию Istio | `kubectl label ns app istio-injection=enabled` |
| Пересоздать поды после метки | `kubectl rollout restart deployment -n app` |
| Hostname для ExternalDNS | аннотация `external-dns.alpha.kubernetes.io/hostname: api.example.com` |
| Выпуск сертификата cert-manager | аннотация `cert-manager.io/cluster-issuer: letsencrypt-prod` + `spec.tls` |
| Статус сертификата | `kubectl get certificate,certificaterequest,order,challenge -A` |
| Почему не выпускается | `kubectl describe challenge <name>` |
| Пулы MetalLB | `kubectl get ipaddresspools,l2advertisements -n metallb-system` |

## Типовые значения

| Параметр | Значение |
| :--- | :--- |
| Service CIDR (kubeadm) / Pod CIDR (Flannel) | `10.96.0.0/12` / `10.244.0.0/16` |
| ClusterIP CoreDNS | `10.96.0.10` |
| `ndots` в поде | 5 (имя с <5 точками идёт по search-доменам) |
| NodeLocal DNSCache | `169.254.20.10` |
| NodePort-диапазон | 30000–32767 |
| VXLAN порт | UDP 4789 (IANA), Flannel — 8472 |
| EndpointSlice | до 100 адресов в слайсе |
| Сертификат Istio (SPIFFE) | ~24 ч, ротация через SDS |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| Service не отвечает | EndpointSlice пуст → selector ≠ labels или поды не Ready |
| DNS-таймауты ровно 5 с | гонки conntrack UDP → NodeLocal DNSCache, `conntrack -S` |
| Медленный резолв внешних имён | `ndots:5` → FQDN с точкой в конце или `dnsConfig.options` |
| Мелкие запросы ок, крупные виснут | MTU overlay, `ping -M do` |
| Приложение видит IP ноды вместо клиента | `externalTrafficPolicy: Cluster` → `Local` / PROXY protocol |
| `LoadBalancer` вечно `<pending>` | нет cloud-controller-manager → MetalLB |
| NetworkPolicy не действует | CNI без поддержки (Flannel) |
| gRPC бьёт в один под | L4-балансировка соединений → mesh / client-side LB / headless |
| 503 между сервисами в mesh | истёкшие сертификаты при недоступном istiod |

## Ловушки

- ⚠️ Default deny egress без правила на DNS ломает всё — сразу добавьте
  allow-dns.
- ⚠️ `port-forward svc/...` — туннель к одному поду, балансировку им не
  проверить.
- ClusterIP не пингуется: это не интерфейс, а правило DNAT.
- Ingress-контроллер ходит прямо на IP подов из EndpointSlice, минуя
  ClusterIP.

> Проверка: kubectl-команды сверены с `--help` (v1.34.1); NetworkPolicy
> из сниппета, `expose`, EndpointSlice, CoreDNS/kube-proxy ConfigMap
> прогнаны на временном kind-кластере (`--dry-run=server` и apply);
> не проверено: Istio, cert-manager, MetalLB, Gateway API CRD, `ipvsadm`,
> `conntrack`, `nft` на ноде кластера.
