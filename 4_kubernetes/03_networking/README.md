# 03. Сеть в Kubernetes

## Зачем
"Service не отвечает", потерянный IP клиента, 502 от Ingress, DNS-
задержки — самые частые сетевые инциденты в кластере. Тема объясняет
путь пакета от пода к поду и к Service, работу kube-proxy и CNI,
Ingress/Gateway API, NetworkPolicy и Service Mesh, чтобы такие
проблемы разбирать по слоям.

## Пререквизиты
- [2_networking](../../2_networking/) — IP, маршрутизация, NAT, DNS,
  L4 vs L7.
- [3_containers/03_networking](../../3_containers/03_networking/) —
  network namespaces и veth.
- [02_workloads](../02_workloads/) — Deployment и readiness probe.

## Файлы
- [01_theory/01_k8s_networking.md](./01_theory/01_k8s_networking.md) —
  Service vs Ingress vs Gateway API, Ingress Controller, NetworkPolicy,
  Service Mesh (mTLS, L7-балансировка), ExternalDNS, cert-manager,
  MetalLB.
- [01_theory/02_k8s_networking_flow.md](./01_theory/02_k8s_networking_flow.md)
  — глубже: путь пакета Pod-to-Pod (veth, VXLAN, BGP), ClusterIP через
  iptables, IPVS и eBPF, externalTrafficPolicy, egress, DNS, как CNI
  применяет NetworkPolicy.
- [02_examples/networking-demo.yaml](./02_examples/networking-demo.yaml)
  — Service (ClusterIP, headless, NodePort), Ingress, NetworkPolicy.
- Отдельных упражнений нет: NetworkPolicy отрабатывается в
  [06_security/01_core](../06_security/01_core/03_exercises/README.md),
  Service — в упражнениях [00_first_steps](../00_first_steps/).

## Как проходить
1. `01_k8s_networking.md` — концепции.
2. `02_k8s_networking_flow.md` — механика; параллельно смотреть
   `iptables-save` и `ip route` внутри ноды kind
   (`docker exec -it <нода> bash`).
3. Применить `networking-demo.yaml` и проверить EndpointSlice и правила
   kube-proxy для созданных Service.

## Когда двигаться дальше
- Можете нарисовать путь пакета от пода к ClusterIP и обратно с
  указанием, где происходит DNAT.
- Можете объяснить, почему Ingress Controller обходит ClusterIP и
  когда теряется IP клиента.
- Можете написать default deny NetworkPolicy и не забыть про DNS.

Дальше — [04_storage](../04_storage/).
