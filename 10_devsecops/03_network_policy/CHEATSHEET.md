# NetworkPolicy — шпаргалка

Подробности и объяснения — в
[01_theory/network_policy.md](./01_theory/network_policy.md).
⚠️ — опасная команда или частая ловушка.

## Семантика

| Правило | Суть |
| :--- | :--- |
| Нет ни одной политики на Pod | весь трафик разрешён |
| Pod выбран хоть одной политикой с `Ingress` | входящий — только то, что разрешено (allow-list) |
| Несколько политик на Pod | объединение (OR) разрешений; deny в стандартном API нет |
| `policyTypes` без правил | deny-all по этому направлению |
| Ответный трафик | разрешён автоматически (stateful, conntrack) |
| Порты | L3/L4 только: IP, порт, протокол; без L7 и FQDN |
| CNI | Calico, Cilium — да; Flannel — нет (политики молча игнорируются ⚠️) |

## Селекторы: AND vs OR ⚠️

| YAML в `from:` / `to:` | Смысл |
| :--- | :--- |
| `- namespaceSelector: {...}`<br>`  podSelector: {...}` (один элемент) | Pod'ы с меткой **в** namespace с меткой (AND) |
| `- namespaceSelector: {...}`<br>`- podSelector: {...}` (два элемента) | любой Pod того namespace **или** Pod'ы своего namespace (OR) |
| `podSelector: {}` в `from` | все Pod'ы своего namespace |
| `namespaceSelector: {}` | все Pod'ы всех namespace |
| `ipBlock: {cidr, except}` | внешние IP; Pod IP сюда лучше не писать |

Метка namespace, которая есть всегда (1.21+):
`kubernetes.io/metadata.name: <имя>`.

## Шаблоны

```yaml
# default deny: весь вход и выход в namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: default-deny-all, namespace: prod}
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
---
# DNS для всех Pod'ов (иначе egress-deny ломает резолв)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-dns, namespace: prod}
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - to:
        - namespaceSelector:
            matchLabels: {kubernetes.io/metadata.name: kube-system}
          podSelector:
            matchLabels: {k8s-app: kube-dns}
      ports:
        - {protocol: UDP, port: 53}
        - {protocol: TCP, port: 53}
---
# Prometheus из namespace monitoring -> метрики всех Pod'ов (AND)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-monitoring, namespace: prod}
spec:
  podSelector: {}
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels: {kubernetes.io/metadata.name: monitoring}
          podSelector:
            matchLabels: {app: prometheus}
      ports:
        - {protocol: TCP, port: 9090}
```

| Задача | Фрагмент |
| :--- | :--- |
| frontend → backend:8080 | `podSelector: {matchLabels: {app: backend}}` + `from: [{podSelector: {matchLabels: {app: frontend}}}]`, `ports: [{port: 8080}]` |
| Выход во внешний CIDR, кроме метаданных облака | `to: [{ipBlock: {cidr: 0.0.0.0/0, except: [169.254.169.254/32]}}]` |
| Диапазон портов (1.25+) | `ports: [{protocol: TCP, port: 32000, endPort: 32768}]` |
| Именованный порт контейнера | `ports: [{port: http}]` |

## Проверка и отладка

| Задача | Команда |
| :--- | :--- |
| Политики namespace | `kubectl get netpol -n prod` |
| Какие Pod'ы выбирает политика | `kubectl describe netpol allow-monitoring -n prod` (Pod Selector) → `kubectl get pods -n prod -l app=backend` |
| Метки namespace | `kubectl get ns --show-labels` |
| Тест-Pod с сетевыми утилитами | `kubectl run netdebug -it --rm --image=nicolaka/netshoot --restart=Never -n prod -- bash` |
| Проверить порт | `nc -zv -w 2 postgres 5432` / `curl -m 2 http://backend:8080` |
| Тест от имени Pod с метками | `kubectl run t -it --rm --image=nicolaka/netshoot --restart=Never -l app=frontend -n prod -- bash` |
| Cilium: отброшенные пакеты | `cilium monitor --type drop` / `hubble observe --verdict DROPPED -n prod` |
| Calico: политики | `calicoctl get networkpolicy -n prod` |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| После egress-deny всё «timeout», даже по имени | нет разрешения DNS (UDP+TCP 53 к kube-dns) |
| Политика есть, но трафик проходит | CNI без поддержки NetworkPolicy; селектор не совпал с метками |
| Разрешили namespace, а пускает весь namespace | селекторы в двух элементах списка (OR) вместо одного (AND) |
| Не работает `namespaceSelector: {name: x}` | у namespace нет метки `name`; использовать `kubernetes.io/metadata.name` |
| Не ходит к apiserver из Pod | egress к IP control plane / `kubernetes.default` (ipBlock), порт 443/6443 |
| `ipBlock` с Pod IP нестабилен | Pod IP меняются — выбирать через `podSelector` |

> Проверка: YAML прогнан через `yamllint` и `kubeconform` (схема
> Kubernetes); не проверено: поведение в живом кластере с CNI,
> `cilium`/`hubble`/`calicoctl` (нет локально).
