#!/usr/bin/env bash
# Ответ: команды для упражнений Helm

CHART_DIR="../../02_examples/myapp"

echo "=== Упражнение 01: установить chart ==="
helm install myapp "$CHART_DIR" \
    --set replicaCount=2 \
    --wait --timeout 2m

kubectl get pods -l app.kubernetes.io/instance=myapp

echo -e "\n=== Упражнение 02: обновить и откатить ==="
helm upgrade myapp "$CHART_DIR" \
    --set image.tag=1.25 \
    --wait

echo "История релизов:"
helm history myapp

echo "Откат к ревизии 1:"
helm rollback myapp 1 --wait

echo -e "\n=== Упражнение 03: Bitnami PostgreSQL ==="
helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
helm repo update

helm install my-postgres bitnami/postgresql \
    --set auth.postgresPassword=secret123 \
    --set primary.persistence.size=1Gi \
    --create-namespace -n database \
    --wait --timeout 5m

kubectl get pods -n database
echo "PG connection: postgresql://postgres:secret123@my-postgres-postgresql.database:5432/postgres"

echo -e "\n=== Упражнение 04: helm diff ==="
helm plugin install https://github.com/databus23/helm-diff 2>/dev/null || true
helm diff upgrade my-postgres bitnami/postgresql \
    --set auth.postgresPassword=newsecret \
    -n database

echo -e "\n=== Cleanup ==="
helm uninstall myapp
helm uninstall my-postgres -n database
