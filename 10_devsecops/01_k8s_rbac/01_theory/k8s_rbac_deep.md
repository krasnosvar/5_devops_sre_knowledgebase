# Kubernetes RBAC — глубоко

## Аутентификация vs Авторизация

**Аутентификация** — кто ты?
- X.509 сертификаты (kubectl использует это)
- Bearer tokens (ServiceAccount tokens)
- OIDC (внешний IdP: Dex, Keycloak, Google)
- Webhook token auth

**Авторизация** — что тебе можно? (RBAC решает это)

```bash
# посмотреть куbeconfig (как kubectl аутентифицируется)
kubectl config view --raw

# декодировать сертификат пользователя
kubectl config view --raw -o jsonpath='{.users[0].user.client-certificate-data}' \
  | base64 -d | openssl x509 -text -noout | grep Subject
```

## Иерархия объектов RBAC

```
ClusterRole           — права на уровне кластера
    ↓ ClusterRoleBinding
User / Group / ServiceAccount

Role (namespace)      — права в одном namespace
    ↓ RoleBinding
User / Group / ServiceAccount

Тонкость: ClusterRole через RoleBinding = права только в одном namespace!
```

```bash
# это разные вещи:
# 1. ClusterRoleBinding → cluster-wide права
kubectl create clusterrolebinding alice-cluster-admin \
  --clusterrole=cluster-admin --user=alice

# 2. RoleBinding → только в namespace "production"
kubectl create rolebinding alice-prod-admin \
  --clusterrole=cluster-admin \
  --user=alice \
  --namespace=production
```

## Встроенные ClusterRoles

```bash
kubectl get clusterroles | grep -E "^(admin|edit|view|cluster-admin)"

# cluster-admin — полный доступ ко всему
# admin — полный доступ в namespace, кроме resource quotas и namespace management
# edit — чтение и запись большинства ресурсов, без управления RBAC
# view — только чтение
```

## Принцип наименьших привилегий — практика

```yaml
# НЕ давать cluster-admin ServiceAccount'у приложения
# НИКОГДА не делать этого в production:
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: app-full-access  # red flag
subjects:
  - kind: ServiceAccount
    name: myapp
roleRef:
  kind: ClusterRole
  name: cluster-admin    # red flag

---
# ПРАВИЛЬНО: минимально необходимые права
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: myapp-role
  namespace: production
rules:
  # Только то, что реально нужно приложению
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch"]
    resourceNames: ["myapp-config"]   # только конкретный ConfigMap!

  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get"]
    resourceNames: ["myapp-secret"]   # только конкретный Secret!
```

## ResourceNames — права на конкретный объект

```yaml
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list"]     # list нельзя ограничить по resourceNames
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "update"]
    resourceNames: ["myapp-tls", "myapp-db"]  # только эти два секрета
```

## Аудит прав — что запускать регулярно

```bash
# Найти все ClusterRoleBindings с cluster-admin
kubectl get clusterrolebindings \
  -o jsonpath='{range .items[?(@.roleRef.name=="cluster-admin")]}{.metadata.name}{"\t"}{.subjects}{"\n"}{end}'

# Найти ServiceAccounts с правами на secrets
kubectl get rolebindings,clusterrolebindings -A \
  -o json | jq '
    .items[] |
    select(.roleRef.name | test("secret|admin|edit")) |
    {name: .metadata.name, ns: .metadata.namespace, subjects: .subjects}
  '

# Все права конкретного ServiceAccount
kubectl auth can-i --list \
  --as=system:serviceaccount:production:myapp \
  -n production

# Кто может делать определённые действия
kubectl who-can create pods -n production
kubectl who-can delete secrets -n production
kubectl who-can update deployments --all-namespaces

# rakkess — матрица прав для ServiceAccount
kubectl rakkess --sa production:myapp -n production
```

## Типичные антипаттерны RBAC

```yaml
# АНТИПАТТЕРН 1: wildcard resources
rules:
  - apiGroups: ["*"]       # red flag
    resources: ["*"]       # red flag
    verbs: ["*"]           # red flag

# АНТИПАТТЕРН 2: automountServiceAccountToken: true (default!)
# Каждый Pod получает токен SA — если приложению не нужны k8s API права, отключить
spec:
  automountServiceAccountToken: false   # правильно для большинства Pod

# АНТИПАТТЕРН 3: права на secrets в неправильном scope
kind: ClusterRole    # права на secrets во ВСЁМ кластере — нужно ли?
rules:
  - resources: ["secrets"]
    verbs: ["get", "list", "watch"]

# АНТИПАТТЕРН 4: shared ServiceAccount для разных сервисов
# Если скомпрометирован один — скомпрометированы все
```

## Создать kubeconfig для ограниченного пользователя

```bash
# 1. Создать ключ и CSR
openssl genrsa -out alice.key 2048
openssl req -new -key alice.key -out alice.csr -subj "/CN=alice/O=developers"

# 2. Создать CertificateSigningRequest в k8s
kubectl apply -f - <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: alice
spec:
  request: $(cat alice.csr | base64 | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 31536000  # 1 год
  usages: [client auth]
EOF

# 3. Одобрить CSR
kubectl certificate approve alice

# 4. Получить подписанный сертификат
kubectl get csr alice -o jsonpath='{.status.certificate}' | base64 -d > alice.crt

# 5. Создать kubeconfig
kubectl config set-credentials alice \
  --client-certificate=alice.crt \
  --client-key=alice.key \
  --embed-certs=true

kubectl config set-context alice@mycluster \
  --cluster=mycluster \
  --user=alice

# 6. Создать RBAC для alice
kubectl create rolebinding alice-view \
  --clusterrole=view \
  --user=alice \
  --namespace=production
```
