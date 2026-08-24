# Kubernetes Networking

## Ingress — HTTP/HTTPS роутинг в кластер

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
    - hosts: [myapp.example.com]
      secretName: myapp-tls
  rules:
    - host: myapp.example.com
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: api-service
                port:
                  number: 80
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend-service
                port:
                  number: 80
```

## Gateway API — замена Ingress (k8s 1.28+ stable)

```yaml
# GatewayClass (один раз на кластер)
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: nginx
spec:
  controllerName: k8s.nginx.org/nginx-gateway-controller

---
# Gateway (один на namespace или общий)
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: main-gateway
spec:
  gatewayClassName: nginx
  listeners:
    - name: https
      port: 443
      protocol: HTTPS
      tls:
        mode: Terminate
        certificateRefs:
          - name: wildcard-cert

---
# HTTPRoute (у каждой команды своё)
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: myapp
spec:
  parentRefs:
    - name: main-gateway
  hostnames: [myapp.example.com]
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /api
      backendRefs:
        - name: api-service
          port: 80
          weight: 90         # canary: 90% на v1
        - name: api-service-v2
          port: 80
          weight: 10         # 10% на v2
```

## NetworkPolicy — L3/L4 firewall в k8s

```yaml
# Default deny: запретить весь входящий трафик в namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: production
spec:
  podSelector: {}          # все поды в namespace
  policyTypes: [Ingress]
  # нет ingress rules = запрещён весь входящий трафик

---
# Разрешить трафик только от api к database
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-to-db
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: postgres
  policyTypes: [Ingress]
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: api
      ports:
        - protocol: TCP
          port: 5432

---
# Разрешить egress только к конкретным namespace и внешним IP
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-egress
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes: [Egress]
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              name: production
    - to:
        - ipBlock:
            cidr: 10.0.0.0/8    # внутренняя сеть
    - ports:                      # DNS всегда разрешить
        - protocol: UDP
          port: 53
```

## Отладка сети в k8s

```bash
# запустить debug pod с сетевыми утилитами
kubectl run netdebug -it --rm \
  --image=nicolaka/netshoot \
  --restart=Never -- bash

# внутри: curl, nslookup, dig, tcpdump, iperf3, netstat, ss, ip

# проверить DNS
nslookup myservice.mynamespace.svc.cluster.local

# проверить подключение к сервису
curl -v http://myservice.mynamespace.svc.cluster.local

# tcpdump на ноде (для отладки CNI)
# найти veth pair Pod
kubectl get pod mypod -o json | jq '.status.hostIP'
ip link show | grep veth

# посмотреть iptables правила для Service
iptables -t nat -L KUBE-SERVICES -n | grep <ClusterIP>

# проверить endpoints (куда фактически идёт трафик)
kubectl get endpoints myservice
kubectl describe endpoints myservice
```

## Cilium — eBPF networking

```bash
# установить Cilium CLI
cilium install

# статус
cilium status

# тест связности
cilium connectivity test

# Network Policy enforcement
cilium policy get

# мониторинг трафика (без tcpdump)
cilium monitor --type drop    # показать отброшенные пакеты
hubble observe --namespace production   # L7 трафик (если Hubble включён)
```
