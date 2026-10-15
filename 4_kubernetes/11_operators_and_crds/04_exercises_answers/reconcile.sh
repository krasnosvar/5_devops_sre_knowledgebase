#!/usr/bin/env bash
# Упражнение 03: игрушечный "оператор" для Website поверх kubectl.
# Каждые INTERVAL секунд сравнивает желаемое (CR Website) с фактическим
# (Deployment website-<name>) и устраняет разницу:
#   - нет Deployment          -> создать (nginx, replicas из spec);
#   - replicas не совпадают   -> kubectl scale;
#   - Website удалён          -> удалить его Deployment;
#   - записать status.phase в CR.
# Запуск: ./reconcile.sh            — бесконечный цикл
#         ./reconcile.sh --once     — один проход (удобно для проверки)
set -euo pipefail

NAMESPACE="${NAMESPACE:-default}"
INTERVAL="${INTERVAL:-5}"
LABEL="example.com/website"

kubectl get crd websites.example.com >/dev/null

reconcile_once() {
    local name desired actual deploy

    # 1. Желаемое состояние: все Website и их spec.replicas
    while read -r name desired; do
        [[ -z "$name" ]] && continue
        deploy="website-${name}"
        if ! kubectl -n "$NAMESPACE" get deployment "$deploy" >/dev/null 2>&1; then
            echo "create  $deploy (replicas=$desired)"
            kubectl -n "$NAMESPACE" create deployment "$deploy" \
                --image=nginx:alpine --replicas="$desired" >/dev/null
            kubectl -n "$NAMESPACE" label deployment "$deploy" \
                "$LABEL=$name" >/dev/null
        else
            actual=$(kubectl -n "$NAMESPACE" get deployment "$deploy" \
                -o jsonpath='{.spec.replicas}')
            if [[ "$actual" != "$desired" ]]; then
                echo "scale   $deploy $actual -> $desired"
                kubectl -n "$NAMESPACE" scale deployment "$deploy" \
                    --replicas="$desired" >/dev/null
            fi
        fi
        kubectl -n "$NAMESPACE" patch website "$name" --subresource=status \
            --type=merge -p '{"status":{"phase":"Reconciled"}}' >/dev/null
    done < <(kubectl -n "$NAMESPACE" get websites \
        -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.replicas}{"\n"}{end}')

    # 2. Сироты: Deployment есть, а Website уже удалён
    while read -r deploy name; do
        [[ -z "$deploy" ]] && continue
        if ! kubectl -n "$NAMESPACE" get website "$name" >/dev/null 2>&1; then
            echo "delete  $deploy (Website $name удалён)"
            kubectl -n "$NAMESPACE" delete deployment "$deploy" >/dev/null
        fi
    done < <(kubectl -n "$NAMESPACE" get deployments -l "$LABEL" \
        -o jsonpath="{range .items[*]}{.metadata.name}{\" \"}{.metadata.labels.example\.com/website}{\"\n\"}{end}")
}

if [[ "${1:-}" == "--once" ]]; then
    reconcile_once
    exit 0
fi

while true; do
    reconcile_once
    sleep "$INTERVAL"
done
