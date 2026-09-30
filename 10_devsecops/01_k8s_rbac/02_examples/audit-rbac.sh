#!/usr/bin/env bash
# Аудит RBAC прав в k8s кластере

echo "=== ClusterRoleBindings с cluster-admin ==="
kubectl get clusterrolebindings \
    -o jsonpath='{range .items[?(@.roleRef.name=="cluster-admin")]}{.metadata.name}{"\t"}{.subjects[*].name}{"\n"}{end}'

echo -e "\n=== ServiceAccounts с широкими правами ==="
kubectl get rolebindings,clusterrolebindings -A -o json 2>/dev/null \
    | jq -r '.items[] |
        select(.roleRef.name | test("admin|edit|cluster-admin")) |
        "\(.metadata.namespace // "cluster")\t\(.metadata.name)\t\(.roleRef.name)"' \
    | sort | head -20

echo -e "\n=== Pods с automountServiceAccountToken=true ==="
kubectl get pods -A -o json \
    | jq -r '.items[] |
        select(.spec.automountServiceAccountToken // true == true) |
        "\(.metadata.namespace)\t\(.metadata.name)\t\(.spec.serviceAccountName // "default")"' \
    | head -20

echo -e "\n=== Pods запущенные от root (runAsNonRoot не установлен) ==="
kubectl get pods -A -o json \
    | jq -r '.items[] |
        select(
            (.spec.securityContext.runAsNonRoot == null or .spec.securityContext.runAsNonRoot == false) and
            (.spec.containers[0].securityContext.runAsNonRoot == null or .spec.containers[0].securityContext.runAsNonRoot == false)
        ) |
        "\(.metadata.namespace)\t\(.metadata.name)"' \
    | head -20

echo -e "\n=== Privileged containers ==="
kubectl get pods -A -o json \
    | jq -r '.items[] |
        .metadata as $meta |
        .spec.containers[] |
        select(.securityContext.privileged == true) |
        "\($meta.namespace)\t\($meta.name)\t\(.name)"'

echo -e "\n=== Права конкретного ServiceAccount ==="
echo "(Пример: проверить default SA в kube-system)"
kubectl auth can-i --list \
    --as=system:serviceaccount:kube-system:default \
    -n kube-system 2>/dev/null | head -15
