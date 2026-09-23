#!/usr/bin/env bash
# Шпаргалка по troubleshooting k8s кластера

echo "=== Node status ==="
kubectl get nodes -o wide
kubectl top nodes 2>/dev/null || echo "(metrics-server не установлен)"

echo -e "\n=== Проблемные Pod'ы ==="
kubectl get pods -A --field-selector='status.phase!=Running,status.phase!=Succeeded' 2>/dev/null \
    | grep -v "^NAMESPACE" || echo "Все Pod'ы в норме"

echo -e "\n=== CrashLoopBackOff ==="
kubectl get pods -A | grep CrashLoopBackOff || echo "Нет CrashLoopBackOff"

echo -e "\n=== OOMKilled за последние 10 минут ==="
kubectl get events -A --field-selector reason=OOMKilling \
    --sort-by='.lastTimestamp' 2>/dev/null | tail -5

echo -e "\n=== Pending Pods (scheduler не может разместить) ==="
kubectl get events -A --field-selector reason=FailedScheduling \
    --sort-by='.lastTimestamp' 2>/dev/null | tail -5

echo -e "\n=== Ресурсы нод ==="
kubectl describe nodes 2>/dev/null | grep -A 5 "Allocated resources:" | head -30

echo -e "\n=== etcd health (если доступен) ==="
kubectl get componentstatuses 2>/dev/null || echo "(componentstatuses устарели в 1.19+)"

echo -e "\n=== Последние события (все namespace) ==="
kubectl get events -A --sort-by='.lastTimestamp' 2>/dev/null | tail -15

# ── Функции для частых операций ──────────────────────────────────────────────
# Быстрый debug pod
debug_pod() {
    local namespace=${1:-default}
    kubectl run netdebug -it --rm \
        --image=nicolaka/netshoot \
        --restart=Never \
        -n "$namespace" \
        -- bash
}

# Логи всех pod'ов по label
logs_by_label() {
    local label=$1 namespace=${2:-default}
    kubectl logs -l "$label" -n "$namespace" --all-containers --tail=50
}

# Exec в первый pod по label
exec_by_label() {
    local label=$1 namespace=${2:-default}
    local pod
    pod=$(kubectl get pod -l "$label" -n "$namespace" -o name | head -1)
    kubectl exec -it "$pod" -n "$namespace" -- sh
}

echo -e "\nФункции доступны: debug_pod, logs_by_label, exec_by_label"
echo "Пример: debug_pod production | logs_by_label 'app=myapp'"
