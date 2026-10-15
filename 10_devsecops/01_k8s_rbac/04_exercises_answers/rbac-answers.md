# Ответы — Kubernetes RBAC

Манифесты ответов:
[alice-rbac.yaml](./alice-rbac.yaml) (упражнение 01),
[myapp-rbac.yaml](./myapp-rbac.yaml) (упражнение 02),
[fixed-rbac.yaml](./fixed-rbac.yaml) (упражнение 04).
Команды выполняются из каталога `10_devsecops/01_k8s_rbac/` на kind
кластере (контекст `kind-kind`). Имена, даты и порядок строк у вас
будут другими.

## Упражнение 01 — Создать ограниченного пользователя

Сначала права (Role + RoleBinding), потом сертификат и kubeconfig:

```bash
kubectl apply -f 04_exercises_answers/alice-rbac.yaml

# Ключ и CSR: CN станет именем пользователя, O — группой
openssl genrsa -out alice.key 2048
openssl req -new -key alice.key -out alice.csr -subj "/CN=alice/O=developers"

kubectl apply -f - <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: alice
spec:
  request: $(base64 -w 0 alice.csr)
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages: ["client auth"]
EOF

kubectl certificate approve alice
kubectl get csr alice -o jsonpath='{.status.certificate}' | base64 -d > alice.crt

kubectl config set-credentials alice \
  --client-certificate=alice.crt --client-key=alice.key --embed-certs=true
kubectl config set-context alice@kind-kind --cluster=kind-kind --user=alice

# Проверка через impersonation (от имени админа)
kubectl auth can-i list pods -n production --as=alice
kubectl auth can-i delete pods -n production --as=alice
kubectl auth can-i get secrets -n production --as=alice

# Проверка с настоящими учётными данными alice
kubectl --context alice@kind-kind get pods -n production
kubectl --context alice@kind-kind get secrets -n production
```

Ожидаемый вывод (примерно так):

```text
namespace/production created
role.rbac.authorization.k8s.io/pod-reader created
rolebinding.rbac.authorization.k8s.io/alice-pod-reader created
certificatesigningrequest.certificates.k8s.io/alice created
certificatesigningrequest.certificates.k8s.io/alice approved
User "alice" set.
Context "alice@kind-kind" created.
yes
no
no
No resources found in production namespace.
Error from server (Forbidden): secrets is forbidden: User "alice" cannot
list resource "secrets" in API group "" in the namespace "production"
```

Почему так: Kubernetes не хранит пользователей — пользователь существует
только как CN в сертификате, подписанном CA кластера. Права даёт Role в
одном namespace; `pods/log` — отдельный subresource, без него
`kubectl logs` будет запрещён. Готовый ClusterRole `view` тоже не даёт
читать secrets, но открывает и много лишнего (deployments, configmaps).

После проверки уберите ключи: `rm -f alice.key alice.csr alice.crt`.

## Упражнение 02 — ServiceAccount с минимальными правами

```bash
kubectl create serviceaccount myapp -n default
kubectl apply -f 04_exercises_answers/myapp-rbac.yaml
kubectl wait --for=condition=Ready pod/mypod --timeout=60s

kubectl auth can-i get configmap/app-config \
  --as=system:serviceaccount:default:myapp
kubectl auth can-i list configmaps \
  --as=system:serviceaccount:default:myapp

kubectl exec -it mypod -- sh
```

Внутри Pod (проверяем CA кластера вместо `-k`):

```bash
SA=/var/run/secrets/kubernetes.io/serviceaccount
TOKEN=$(cat $SA/token)
curl -s --cacert $SA/ca.crt -H "Authorization: Bearer $TOKEN" \
  https://kubernetes.default.svc/api/v1/namespaces/default/configmaps/app-config
curl -s --cacert $SA/ca.crt -H "Authorization: Bearer $TOKEN" \
  https://kubernetes.default.svc/api/v1/namespaces/default/configmaps
```

Ожидаемый вывод (примерно так, JSON сокращён):

```text
yes
no
{
  "kind": "ConfigMap",
  "apiVersion": "v1",
  "metadata": { "name": "app-config", "namespace": "default", ... },
  "data": { "LOG_LEVEL": "info" }
}
{
  "kind": "Status",
  "status": "Failure",
  "message": "configmaps is forbidden: User
  \"system:serviceaccount:default:myapp\" cannot list resource
  \"configmaps\" in API group \"\" in the namespace \"default\"",
  "reason": "Forbidden",
  "code": 403
}
```

Почему так: `resourceNames` ограничивает доступ одним объектом, но list
по своей природе возвращает коллекцию, поэтому разрешён только `get`.
Токен SA монтируется в Pod автоматически — если приложению API не нужен
вовсе, ставьте `automountServiceAccountToken: false`.

## Упражнение 03 — Аудит прав

`who-can` и `rakkess` — плагины kubectl, ставятся через krew (rakkess в
krew называется `access-matrix`):

```bash
kubectl krew install who-can access-matrix

# 1. Кто может создавать pods в production
kubectl who-can create pods -n production

# 2. Кто имеет права на secrets (во всех namespace)
kubectl who-can get secrets --all-namespaces

# 3. Что может ServiceAccount default в kube-system
kubectl auth can-i --list \
  --as=system:serviceaccount:kube-system:default -n kube-system
kubectl access-matrix --sa kube-system:default -n kube-system
```

Ожидаемый вывод (примерно так, списки сокращены):

```text
ROLEBINDING  NAMESPACE  SUBJECT  TYPE  SA-NAMESPACE

CLUSTERROLEBINDING                          SUBJECT                    TYPE
cluster-admin                               system:masters             Group
kubeadm:cluster-admins                      kubeadm:cluster-admins     Group
system:controller:replicaset-controller     replicaset-controller      ...
...
Resources                                      Non-Resource URLs  Resource Names  Verbs
selfsubjectreviews.authentication.k8s.io       []                 []              [create]
selfsubjectaccessreviews.authorization.k8s.io  []                 []              [create]
selfsubjectrulesreviews.authorization.k8s.io   []                 []              [create]
                                               [/api/*]           []              [get]
                                               [/healthz]         []              [get]
...
```

Почему так: who-can обходит все RoleBinding/ClusterRoleBinding и
показывает субъектов, чья роль даёт нужный глагол. Pods могут создавать
и системные контроллеры — это нормально. У `default` SA в kube-system
должны быть только discovery-права; если там видны secrets или `*` —
кто-то привязал к нему лишнюю роль.

## Упражнение 04 — Исправить небезопасную конфигурацию

Четыре проблемы в `insecure-rbac.yaml`:

1. `apiGroups/resources/verbs: ["*"]` — wildcard даёт всё, включая
   будущие CRD.
2. `ClusterRole` там, где приложению нужен один namespace → `Role`.
3. `ClusterRoleBinding` выдаёт права во всём кластере → `RoleBinding`
   в namespace `production`.
4. `roleRef` указывает на `cluster-admin`, а не на `app-role` — собственная
   роль вообще не используется.

Исправленный вариант — [fixed-rbac.yaml](./fixed-rbac.yaml):

```bash
kubectl create serviceaccount myapp -n production
kubectl apply -f 04_exercises_answers/fixed-rbac.yaml
kubectl auth can-i list configmaps -n production \
  --as=system:serviceaccount:production:myapp
kubectl auth can-i delete pods -n production \
  --as=system:serviceaccount:production:myapp
kubectl auth can-i list configmaps -n default \
  --as=system:serviceaccount:production:myapp
```

Ожидаемый вывод (примерно так):

```text
serviceaccount/myapp created
role.rbac.authorization.k8s.io/app-role created
rolebinding.rbac.authorization.k8s.io/app-binding created
yes
no
no
```

Почему так: права теперь ограничены одним namespace и конкретным
списком глаголов. Набор ресурсов в `app-role` (только чтение
configmaps) — пример; в реальности его определяют по тому, к каким
объектам API приложение действительно обращается.
