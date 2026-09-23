#!/usr/bin/env bash
# Ответ: упражнение 05 — параллельный деплой с контролем параллельности
set -euo pipefail

# Серверы (в реальности — из файла)
SERVERS=(server1 server2 server3 server4 server5)
MAX_PARALLEL=3
RESULTS=()

deploy_server() {
    local server=$1
    # Имитация деплоя (в реальности: ssh "$server" "systemctl restart nginx")
    sleep "$(( RANDOM % 3 + 1 ))"
    echo "✓ $server: deployed"
}

echo "Deploying to ${#SERVERS[@]} servers (max $MAX_PARALLEL parallel)..."

# Параллельно с ограничением через xargs
printf '%s\n' "${SERVERS[@]}" \
    | xargs -P "$MAX_PARALLEL" -I{} bash -c '
        server={}
        sleep $(( RANDOM % 2 + 1 ))
        echo "✓ $server: OK"
    '

echo -e "\nAlternative: GNU parallel"
# parallel --jobs $MAX_PARALLEL "ssh {} systemctl restart nginx" ::: "${SERVERS[@]}"

echo -e "\nAlternative: background jobs with wait"
PIDS=()
for server in "${SERVERS[@]}"; do
    # Ограничить параллельность вручную
    while (( ${#PIDS[@]} >= MAX_PARALLEL )); do
        for i in "${!PIDS[@]}"; do
            if ! kill -0 "${PIDS[$i]}" 2>/dev/null; then
                unset 'PIDS[$i]'
                PIDS=("${PIDS[@]}")
            fi
        done
        sleep 0.1
    done
    (deploy_server "$server") &
    PIDS+=($!)
done
wait  # ждать все фоновые задачи
echo "All deployments complete"
