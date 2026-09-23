#!/usr/bin/env bash
# Ответы: RBAC упражнения

echo "=== Упражнение 01: создать пользователя alice ==="

# Генерировать ключ и CSR
openssl genrsa -out alice.key 2048
openssl req -new -key alice.key -out alice.csr -subj "/CN=alice/O=developers"

# Создать CertificateSigningRequest в k8s
kubectl apply -f - <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: alice
spec:
  request: $(base64 -w 0 alice.csr)
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages: [client auth]
EOF

# Одобрить
kubectl certificate approve alice

# Получить сертификат
kubectl get csr alice -o jsonpath='{.status.certificate}' | base64 -d > alice.crt

# Создать kubeconfig
kubectl config set-credentials alice \
    --client-certificate=alice.crt \
    --client-key=alice.key \
    --embed-certs=true

kubectl config set-context alice@$(kubectl config current-context) \
    --cluster=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}') \
    --user=alice

# Применить RBAC из 03_exercises
kubectl apply -f ../03_exercises/README.md 2>/dev/null || \
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: alice-pod-reader
  namespace: production
subjects:
  - kind: User
    name: alice
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
EOF

echo -e "\n=== Проверка прав alice ==="
kubectl auth can-i list pods -n production --as=alice       # yes
kubectl auth can-i delete pods -n production --as=alice     # no
kubectl auth can-i get secrets -n production --as=alice     # no

echo -e "\n=== Упражнение 03: аудит прав ==="
echo "Кто может создавать pods:"
kubectl who-can create pods -n production 2>/dev/null || \
    kubectl get rolebindings,clusterrolebindings -A -o json \
    | jq -r '.items[] | select(.roleRef.name | test("admin|cluster-admin")) | "\(.metadata.namespace)\t\(.metadata.name)"'

echo -e "\nServiceAccount default в kube-system:"
kubectl auth can-i --list \
    --as=system:serviceaccount:kube-system:default \
    -n kube-system 2>/dev/null | grep -v "^no$" | head -10

rm -f alice.key alice.csr alice.crt
