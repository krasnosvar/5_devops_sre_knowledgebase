# RBAC и безопасность Kubernetes

## RBAC — модель

```
Subject (кто)     Verb (что)       Resource (на что)
─────────────     ──────────       ─────────────────
User              get              pods
Group             list             deployments
ServiceAccount    create           secrets
                  delete           services
                  patch            configmaps
                  watch            nodes
                  *                *  (все)
```

## Объекты RBAC

**Role** — набор прав в одном namespace.
**ClusterRole** — набор прав на уровне кластера (или шаблон для всех namespace).
**RoleBinding** — привязка Role к Subject в namespace.
**ClusterRoleBinding** — привязка ClusterRole к Subject на уровне кластера.

```yaml
# Role — разрешить читать pods и логи в namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: production
rules:
  - apiGroups: [""]              # "" = core API (pods, services, etc.)
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch"]

---
# RoleBinding — привязать Role к ServiceAccount
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-reader-binding
  namespace: production
subjects:
  - kind: ServiceAccount
    name: monitoring-agent
    namespace: monitoring
  - kind: User
    name: alice@example.com
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

```yaml
# ClusterRole — для ресурсов уровня кластера
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-reader
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["metrics.k8s.io"]
    resources: ["nodes", "pods"]
    verbs: ["get", "list"]
```

## ServiceAccount — идентичность Pod'а

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: myapp
  namespace: production
  annotations:
    # IRSA (AWS EKS): использовать IAM роль
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/myapp-role

---
# Pod использует ServiceAccount
spec:
  serviceAccountName: myapp
  automountServiceAccountToken: false  # не монтировать токен если не нужен
```

```bash
# проверить права ServiceAccount
kubectl auth can-i list pods \
  --as=system:serviceaccount:production:myapp \
  -n production

# посмотреть все права субъекта
kubectl auth can-i --list \
  --as=system:serviceaccount:production:myapp \
  -n production
```

## Инструменты аудита RBAC

```bash
# kubectl-who-can: кто может выполнить действие
kubectl who-can get secrets -n production
kubectl who-can create pods

# rakkess: матрица прав для субъекта
kubectl rakkess --sa production:myapp

# rbac-lookup: права конкретного субъекта
kubectl rbac-lookup myapp --kind ServiceAccount -n production

# kube-score: проверить RBAC в манифестах
kube-score score deployment.yaml
```

## Admission Controllers

Intercept запросы к API server до сохранения в etcd.

**Встроенные (важные):**
- `LimitRanger` — применяет defaults для resource limits
- `ResourceQuota` — ограничивает суммарные ресурсы namespace
- `PodSecurity` — Pod Security Standards
- `MutatingAdmissionWebhook` / `ValidatingAdmissionWebhook` — внешние webhook

**OPA Gatekeeper / Kyverno** — политики через ValidatingWebhook:

```yaml
# Kyverno policy: запрет latest тега
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-latest-tag
spec:
  validationFailureAction: enforce
  rules:
    - name: disallow-latest-tag
      match:
        any:
          - resources:
              kinds: [Pod]
      validate:
        message: "Using latest tag is not allowed"
        pattern:
          spec:
            containers:
              - image: "!*:latest"
```

## Pod Security Standards (PSS)

```yaml
# включить PSS для namespace
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    # enforce: нарушение → Pod не создаётся
    pod-security.kubernetes.io/enforce: restricted
    # warn: нарушение → предупреждение, Pod создаётся
    pod-security.kubernetes.io/warn: restricted
    # audit: нарушение → в audit log
    pod-security.kubernetes.io/audit: restricted
```

Три уровня политик:
- **privileged** — без ограничений
- **baseline** — минимальные (нет privileged containers, hostNetwork, hostPID)
- **restricted** — максимальные (runAsNonRoot, readOnlyRootFilesystem, drop all caps)
