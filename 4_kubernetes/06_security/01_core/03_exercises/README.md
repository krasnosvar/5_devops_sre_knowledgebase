# Упражнения — RBAC и безопасность Kubernetes

Стенд: 🐳 Tier 1 — kind или k3d кластер

```bash
kind create cluster --name lab
```

## 01 — Default deny NetworkPolicy

**Задача:** Применить default-deny к namespace `production`. Убедиться что Pod'ы не могут общаться между собой. Затем добавить политику разрешающую трафик только от frontend к backend.

```bash
kubectl create namespace production

# TODO: применить default-deny-all из 02_examples/networking-demo.yaml
kubectl apply -f ../../../03_networking/02_examples/networking-demo.yaml

# Создать два Pod'а для проверки
kubectl run frontend --image=busybox -n production -- sleep 3600
kubectl run backend  --image=busybox -n production -- sleep 3600

# Проверить: frontend → backend должно быть заблокировано
kubectl exec -n production frontend -- wget -qO- http://backend --timeout=3 || echo "Blocked ✓"

# TODO: добавить NetworkPolicy разрешающую frontend → backend port 80
```

## 02 — Pod Security Standards

**Задача:** Создать namespace с enforce=restricted. Попробовать задеплоить Pod без securityContext (должно быть запрещено). Исправить Pod чтобы соответствовал restricted.

```bash
kubectl create namespace secure-test
kubectl label namespace secure-test pod-security.kubernetes.io/enforce=restricted

# Это упадёт (нет securityContext):
kubectl run bad-pod --image=nginx -n secure-test || echo "Rejected ✓"

# TODO: написать Pod manifest соответствующий restricted PSS
# Подсказка: runAsNonRoot, readOnlyRootFilesystem, drop ALL
```

## 03 — ServiceAccount с минимальными правами

**Задача:** Создать ServiceAccount для приложения, которое должно только читать ConfigMap `app-config` в namespace `production`. Запустить Pod с этим SA и проверить что права работают.

```bash
# TODO: создать ServiceAccount, Role, RoleBinding из answers
kubectl apply -f ../04_exercises_answers/rbac-answer.yaml

# Создать Pod с SA
kubectl run test-pod --image=bitnami/kubectl -n production \
    --serviceaccount=myapp \
    --command -- sleep 3600

# Проверить права внутри Pod
kubectl exec -n production test-pod -- \
    kubectl get configmap app-config -n production   # OK

kubectl exec -n production test-pod -- \
    kubectl get secrets -n production || echo "Forbidden ✓"
```

## 04 — Аудит RBAC

**Задача:** Запустить скрипт аудита и найти ServiceAccount'ы с избыточными правами.

Готового скрипта в этом разделе нет намеренно — аудит "живой" кластерной RBAC
это уже не туториал, а тулза. Она лежит в `10_devsecops`, где собраны такие
готовые инструменты:

```bash
# Аудит кластера
bash ../../../../10_devsecops/01_k8s_rbac/02_examples/audit-rbac.sh

# Найти кто может создавать Pods
kubectl who-can create pods --all-namespaces 2>/dev/null || \
kubectl get clusterrolebindings -o json \
    | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name'
```
