# Kubernetes NetworkPolicy

## Что такое NetworkPolicy

NetworkPolicy — Kubernetes ресурс для ограничения трафика на уровне L3/L4 (IP + порт).
По умолчанию в k8s все Pod'ы могут общаться со всеми Pod'ами.
NetworkPolicy добавляет zero-trust сетевую сегментацию.

**Важно:** NetworkPolicy работает только если CNI плагин её поддерживает.
- Flannel — **не поддерживает** NetworkPolicy
- Calico — поддерживает
- Cilium — поддерживает (+ расширенные L7 политики)
- Weave — поддерживает

## Default Deny — правило нулевого доверия

```yaml
# Запретить весь входящий трафик в namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: production
spec:
  podSelector: {}        # применить ко всем Pod'ам в namespace
  policyTypes:
    - Ingress            # контролировать входящий трафик
  # нет ingress правил = запретить всё

---
# Запретить весь исходящий трафик
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-egress
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Egress
  # нет egress правил = запретить всё
  # ВНИМАНИЕ: заблокирует DNS тоже! Нужно разрешить UDP 53
```

## Базовые примеры

```yaml
# Разрешить трафик только от frontend к backend
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend           # применяется к backend Pod'ам
  policyTypes: [Ingress]
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend  # только от frontend
      ports:
        - protocol: TCP
          port: 8080         # только на порт 8080

---
# Разрешить трафик из другого namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring
  namespace: production
spec:
  podSelector: {}            # все Pod'ы в production
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: monitoring   # из namespace monitoring
        - podSelector:
            matchLabels:
              app: prometheus    # только prometheus
      ports:
        - protocol: TCP
          port: 9090             # только метрики порт
```

## Egress — контроль исходящего трафика

```yaml
# Backend может ходить только к PostgreSQL и DNS
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-egress
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes: [Egress]
  egress:
    # К PostgreSQL в том же namespace
    - to:
        - podSelector:
            matchLabels:
              app: postgres
      ports:
        - protocol: TCP
          port: 5432

    # К Redis в том же namespace
    - to:
        - podSelector:
            matchLabels:
              app: redis
      ports:
        - protocol: TCP
          port: 6379

    # DNS — всегда нужен!
    - to: []               # к любому адресу
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53

    # К внешнему API (по CIDR)
    - to:
        - ipBlock:
            cidr: 54.192.0.0/12   # AWS CloudFront
```

## Типичные паттерны

### Три уровня изоляции

```yaml
# 1. Запретить всё
# → default-deny-ingress + default-deny-egress

# 2. Разрешить DNS
- egress:
    - ports:
        - protocol: UDP
          port: 53

# 3. Разрешить только нужное
- ingress/egress: конкретные сервисы
```

### Микросервисная архитектура

```
frontend → api-gateway → [auth-service, product-service, order-service]
                              ↓
                         [postgres, redis]
```

```yaml
# NetworkPolicy для каждого сервиса
# api-gateway: разрешить ingress от LB, egress к сервисам
# auth-service: ingress только от api-gateway, egress к postgres
# product-service: ingress только от api-gateway, egress к postgres + redis
```

## Отладка NetworkPolicy

```bash
# Проверить какие политики применены к Pod'у
kubectl get networkpolicy -n production

# Cilium — показать правила
cilium policy get
# Показать отброшенные пакеты
cilium monitor --type drop -n production

# Netshoot — дебаг контейнер с сетевыми утилитами
kubectl run netdebug -it --rm \
  --image=nicolaka/netshoot \
  --restart=Never -n production -- bash

# Внутри: попробовать подключиться
curl http://postgres:5432     # должно быть разрешено
curl http://redis:6379        # должно быть разрешено  
curl http://external-api.com  # должно быть заблокировано

# Calico — показать политики
calicoctl get networkpolicy -n production
```

## Ограничения NetworkPolicy

- **Нет L7** (hostname, HTTP метод, заголовки) — используйте Cilium NetworkPolicy или service mesh (Istio)
- **Нет логирования** по умолчанию — Cilium Hubble или eBPF для видимости
- **Нет deny правил** в стандартном API — только allow; deny через Calico GlobalNetworkPolicy
- **FQDN egress** не поддерживается — только IP/CIDR; для hostname нужен Cilium
