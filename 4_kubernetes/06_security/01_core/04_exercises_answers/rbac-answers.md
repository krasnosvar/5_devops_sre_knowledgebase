# Ответы — RBAC и безопасность Kubernetes

Манифесты ответов:
[netpol-answer.yaml](./netpol-answer.yaml) (упражнение 01),
[pss-answer.yaml](./pss-answer.yaml) (упражнение 02),
[rbac-answer.yaml](./rbac-answer.yaml) (упражнения 03 и 04).
Команды выполняются из каталога `4_kubernetes/06_security/01_core/`.
Имена подов, IP и время у вас будут другими.

## Упражнение 01 — Default deny NetworkPolicy

Поды и Service создаются командами из условия. Дальше:

```bash
kubectl apply -f 04_exercises_answers/netpol-answer.yaml
kubectl get networkpolicy -n production
kubectl exec -n production frontend -- wget -qO- -T 3 http://backend | grep '<title>'
kubectl exec -n production other -- wget -qO- -T 3 http://backend
```

Ожидаемый вывод (примерно так):

```text
networkpolicy.networking.k8s.io/default-deny-all created
networkpolicy.networking.k8s.io/allow-dns-egress created
networkpolicy.networking.k8s.io/frontend-egress-to-backend created
networkpolicy.networking.k8s.io/backend-ingress-from-frontend created
NAME                            POD-SELECTOR   AGE
allow-dns-egress                <none>         2s
backend-ingress-from-frontend   app=backend    2s
default-deny-all                <none>         2s
frontend-egress-to-backend      app=frontend   2s
<title>Welcome to nginx!</title>
wget: download timed out
command terminated with exit code 1
```

Почему так: политики аддитивны — default deny запрещает всё, а
каждая следующая политика только добавляет разрешения. Для
frontend → backend нужны обе стороны: egress у frontend и ingress у
backend. Без отдельного разрешения DNS (порт 53 к CoreDNS) имя
`backend` не разрешится, и запрос упадёт ещё до TCP.

## Упражнение 02 — Pod Security Standards

```bash
kubectl create namespace secure-test
kubectl label namespace secure-test pod-security.kubernetes.io/enforce=restricted
kubectl run bad-pod --image=nginx -n secure-test
kubectl apply -f 04_exercises_answers/pss-answer.yaml
kubectl wait -n secure-test --for=condition=Ready pod/good-pod --timeout=60s
```

Ожидаемый вывод (примерно так):

```text
namespace/secure-test created
namespace/secure-test labeled
Error from server (Forbidden): pods "bad-pod" is forbidden: violates
PodSecurity "restricted:latest": allowPrivilegeEscalation != false (...),
unrestricted capabilities (...), runAsNonRoot != true (...),
seccompProfile (...)
pod/good-pod created
pod/good-pod condition met
```

Почему так: Pod Security Admission проверяет под при создании и
перечисляет все нарушения профиля сразу. Исправленный под задаёт
`runAsNonRoot` (и непривилегированный UID), `allowPrivilegeEscalation:
false`, `drop: ["ALL"]` и `seccompProfile: RuntimeDefault`. Образ
`nginx` по умолчанию стартует от root, поэтому в ответе взят busybox
с UID 1000.

## Упражнение 03 — ServiceAccount с минимальными правами

```bash
kubectl apply -f 04_exercises_answers/rbac-answer.yaml
kubectl wait -n production --for=condition=Ready pod/test-pod --timeout=120s
kubectl auth can-i get configmap/app-config -n production \
    --as=system:serviceaccount:production:myapp
kubectl auth can-i list secrets -n production \
    --as=system:serviceaccount:production:myapp
kubectl exec -n production test-pod -- sh -c '
  SA=/var/run/secrets/kubernetes.io/serviceaccount
  curl -s -o /dev/null -w "%{http_code}\n" --cacert $SA/ca.crt \
    -H "Authorization: Bearer $(cat $SA/token)" \
    https://kubernetes.default.svc/api/v1/namespaces/production/configmaps/app-config
  curl -s --cacert $SA/ca.crt -H "Authorization: Bearer $(cat $SA/token)" \
    https://kubernetes.default.svc/api/v1/namespaces/production/secrets'
```

Ожидаемый вывод (примерно так):

```text
yes
no
200
{
  "kind": "Status",
  ...
  "message": "secrets is forbidden: User \"system:serviceaccount:production:myapp\"
  cannot list resource \"secrets\" in API group \"\" in the namespace \"production\"",
  "reason": "Forbidden",
  "code": 403
}
```

Почему так: Role разрешает только `get`/`watch` и только на объект
с именем `app-config` (`resourceNames`). У SA выключено
`automountServiceAccountToken`, поэтому в `test-pod` монтирование
токена включено явно на уровне пода — без этого внутри пода не было
бы токена и запрос ушёл бы анонимно.

## Упражнение 04 — Аудит RBAC

```bash
bash ../../../10_devsecops/01_k8s_rbac/02_examples/audit-rbac.sh
kubectl get clusterrolebindings -o json \
    | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name'
kubectl auth can-i --list -n production \
    --as=system:serviceaccount:production:deployer
```

Ожидаемый вывод (примерно так, на чистом kind):

```text
=== ClusterRoleBindings с cluster-admin ===
cluster-admin           system:masters
kubeadm:cluster-admins  kubeadm:cluster-admins

=== ServiceAccounts с широкими правами ===
cluster  cluster-admin                     cluster-admin
cluster  kubeadm:apiserver-kubelet-client  system:kubelet-api-admin
...
cluster-admin
kubeadm:cluster-admins
Resources         Non-Resource URLs   Resource Names   Verbs
deployments.apps  []                  []               [get list watch update]
pods/log          []                  []               [get list watch]
pods              []                  []               [get list watch]
...
```

Почему так: на чистом кластере `cluster-admin` привязан только к
системным группам (`system:masters`, `kubeadm:cluster-admins`) — это
норма. Подозрительны любые другие привязки к `cluster-admin`/`admin`/
`edit`, особенно для ServiceAccount. Как исправлять найденное, показано
в конце [rbac-answer.yaml](./rbac-answer.yaml): вместо ClusterRole с
`*` — namespace-Role с конкретными ресурсами и глаголами для отдельного
SA `deployer`. Плагин `kubectl who-can` ставится через krew; без него
команда из условия переходит к jq-запросу.
