# Упражнения — RBAC и безопасность Kubernetes

Стенд: 🐳 Tier 1 — kind или k3d кластер

Ответы: [04_exercises_answers/rbac-answers.md](../04_exercises_answers/rbac-answers.md).

```bash
kind create cluster --name lab
```

## 01 — Default deny NetworkPolicy

**Задача:** Применить default-deny к namespace `production`. Убедиться,
что поды не могут общаться между собой. Затем добавить политики,
разрешающие трафик только от frontend к backend на порт 80.

NetworkPolicy применяет CNI-плагин. В свежих версиях kind встроенный
kindnet их поддерживает; если у вас трафик после default deny всё
равно проходит — CNI политики не применяет (см.
[03_networking](../../../03_networking/) §3), поставьте Calico или
Cilium.

```bash
kubectl create namespace production

# backend (nginx) + Service с тем же именем; frontend и "чужой" под
kubectl run backend --image=nginx:1.27-alpine -n production \
    --labels=app=backend --port=80 --expose
kubectl run frontend --image=busybox:1.36 -n production \
    --labels=app=frontend -- sleep 3600
kubectl run other --image=busybox:1.36 -n production \
    --labels=app=other -- sleep 3600

# До политик: frontend → backend работает
kubectl exec -n production frontend -- wget -qO- -T 3 http://backend

# Написать и применить: default-deny-all (Ingress + Egress),
# разрешение DNS, frontend → backend:80. Проверить, что frontend
# достаёт backend, а other — нет.
```

## 02 — Pod Security Standards

Что такое Pod Security Standards и уровни privileged/baseline/restricted —
в [10_devsecops/05_pod_security](../../../../10_devsecops/05_pod_security/).

**Задача:** Создать namespace с enforce=restricted. Попробовать задеплоить
Pod без securityContext (должно быть запрещено). Исправить Pod чтобы
соответствовал restricted.

```bash
kubectl create namespace secure-test
kubectl label namespace secure-test pod-security.kubernetes.io/enforce=restricted

# Это упадёт (нет securityContext):
kubectl run bad-pod --image=nginx -n secure-test || echo "Rejected ✓"

# TODO: написать Pod manifest соответствующий restricted PSS
# Подсказка: runAsNonRoot, readOnlyRootFilesystem, drop ALL
```

## 03 — ServiceAccount с минимальными правами

**Задача:** Создать ServiceAccount для приложения, которое должно только
читать ConfigMap `app-config` в namespace `production`. Запустить Pod с этим
SA и проверить что права работают.

Флаг `kubectl run --serviceaccount` удалён из kubectl, поэтому под с
нужным ServiceAccount описывается манифестом через
`spec.serviceAccountName`. Внутри пода права проверяются запросом к
API с токеном ServiceAccount (образ с curl, без kubectl).

```bash
# Написать ServiceAccount, Role (с resourceNames), RoleBinding,
# ConfigMap app-config и Pod test-pod:
#   spec.serviceAccountName: myapp
#   image: curlimages/curl:8.10.1, command: ["sleep", "3600"]
kubectl apply -f my-rbac.yaml

# Проверить права снаружи (от имени SA)
kubectl auth can-i get configmap/app-config -n production \
    --as=system:serviceaccount:production:myapp          # yes
kubectl auth can-i list secrets -n production \
    --as=system:serviceaccount:production:myapp          # no

# Проверить изнутри пода: запрос к API с токеном SA
kubectl exec -n production test-pod -- sh -c '
  SA=/var/run/secrets/kubernetes.io/serviceaccount
  curl -s --cacert $SA/ca.crt -H "Authorization: Bearer $(cat $SA/token)" \
    https://kubernetes.default.svc/api/v1/namespaces/production/configmaps/app-config'
```

## 04 — Аудит RBAC

**Задача:** Запустить скрипт аудита и найти ServiceAccount'ы с избыточными
правами.

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
