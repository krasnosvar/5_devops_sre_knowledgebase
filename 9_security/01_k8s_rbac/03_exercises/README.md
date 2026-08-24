# Упражнения — Kubernetes RBAC

Стенд: 🐳 Tier 1 — kind кластер

## 01 — Создать ограниченного пользователя

**Задача:** Создать пользователя `alice` с правами только читать pods и логи в namespace `production`. Проверить что alice НЕ может удалять pods или читать secrets.

```bash
# TODO: создать Certificate + CSR + kubeconfig для alice
# TODO: создать Role pod-reader в namespace production
# TODO: создать RoleBinding

# Проверка
kubectl auth can-i list pods -n production --as=alice          # must: yes
kubectl auth can-i delete pods -n production --as=alice         # must: no
kubectl auth can-i get secrets -n production --as=alice         # must: no
```

## 02 — ServiceAccount с минимальными правами

**Задача:** Создать ServiceAccount для приложения которое должно только читать ConfigMaps с именем `app-config`. Запустить Pod с этим SA и проверить права.

```bash
kubectl create serviceaccount myapp -n default

# TODO: создать Role и RoleBinding
# TODO: создать Pod с serviceAccountName: myapp

# Внутри Pod проверить права
kubectl exec -it mypod -- sh
# curl -k -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
#   https://kubernetes.default.svc/api/v1/namespaces/default/configmaps/app-config
```

## 03 — Аудит прав

**Задача:** Используя kubectl who-can или rakkess:
1. Найти все субъекты которые могут создавать pods в namespace production
2. Найти все субъекты с правами на secrets
3. Определить что может делать ServiceAccount `default` в namespace `kube-system`

## 04 — Исправить небезопасную конфигурацию

**Задача:** Дан файл `insecure-rbac.yaml` с антипаттернами. Исправить все проблемы.

```yaml
# insecure-rbac.yaml (найти и исправить 4 проблемы)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: app-role
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: app-binding
subjects:
  - kind: ServiceAccount
    name: myapp
    namespace: production
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
```
