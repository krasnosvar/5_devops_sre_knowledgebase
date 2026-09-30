#!/usr/bin/env bash
# Трассировка создания Pod через все компоненты k8s
# Запускать в kind/k3d кластере

echo "=== Создаём Pod и смотрим что происходит ==="

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: trace-demo
  labels:
    app: trace-demo
spec:
  containers:
    - name: app
      image: nginx:alpine
      resources:
        requests: {cpu: 50m, memory: 32Mi}
EOF

echo "Pod создан. Следим за событиями..."
kubectl get events --field-selector involvedObject.name=trace-demo \
    --watch --output-watch-events=true 2>/dev/null &
WATCH_PID=$!

# Ждать Pod'а
kubectl wait pod/trace-demo --for=condition=Ready --timeout=60s

kill $WATCH_PID 2>/dev/null || true

echo -e "\n=== Куда поместил scheduler ==="
kubectl get pod trace-demo -o jsonpath='{.spec.nodeName}'; echo

echo -e "\n=== Полный lifecycle через describe ==="
kubectl describe pod trace-demo | grep -A 20 "Events:"

echo -e "\n=== Pod в API ==="
kubectl get pod trace-demo -o json | jq '{
  phase: .status.phase,
  node: .spec.nodeName,
  podIP: .status.podIP,
  startTime: .status.startTime,
  containerState: .status.containerStatuses[0].state
}'

kubectl delete pod trace-demo --grace-period=0
