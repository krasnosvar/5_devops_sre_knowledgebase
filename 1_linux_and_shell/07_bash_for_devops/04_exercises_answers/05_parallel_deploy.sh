#!/usr/bin/env bash
# Ответ: упражнение 05 — параллельный рестарт nginx на списке серверов.
# Использование: bash 05_parallel_deploy.sh servers.txt
#   servers.txt — по одному хосту на строку; пустые строки и # пропускаются.
# Нужен bash >= 4.3 (wait -n) и вход по ssh-ключу без пароля (BatchMode).
set -euo pipefail

MAX_PARALLEL=3
SERVERS_FILE=${1:?Использование: $0 servers.txt}
if [[ ! -r $SERVERS_FILE ]]; then
    echo "ERROR: не читается $SERVERS_FILE" >&2
    exit 1
fi

RESULTS_DIR=$(mktemp -d)
trap 'rm -rf "$RESULTS_DIR"' EXIT

# Выполняется в фоне для одного сервера: пишет код возврата и вывод в
# отдельные файлы, чтобы параллельные задачи не перемешивали stdout
deploy_one() {
    local server=$1 rc=0
    ssh -n -o BatchMode=yes -o ConnectTimeout=5 "$server" \
        "sudo systemctl restart nginx" >"$RESULTS_DIR/$server.log" 2>&1 \
        || rc=$?
    echo "$rc" >"$RESULTS_DIR/$server.rc"
}

mapfile -t SERVERS < <(grep -vE '^[[:space:]]*(#|$)' "$SERVERS_FILE")
(( ${#SERVERS[@]} > 0 )) || { echo "ERROR: $SERVERS_FILE пуст" >&2; exit 1; }
echo "Restarting nginx on ${#SERVERS[@]} servers, max $MAX_PARALLEL parallel"

running=0
for server in "${SERVERS[@]}"; do
    if (( running >= MAX_PARALLEL )); then
        wait -n          # дождаться завершения ЛЮБОЙ одной фоновой задачи
        running=$(( running - 1 ))
    fi
    deploy_one "$server" &
    running=$(( running + 1 ))
done
wait                     # дождаться оставшихся

# Сбор результатов: отчёт по каждому серверу и общий код выхода
failed=0
for server in "${SERVERS[@]}"; do
    rc=$(<"$RESULTS_DIR/$server.rc")
    if [[ $rc == 0 ]]; then
        echo "OK     $server"
    else
        echo "FAILED $server (exit $rc): $(tail -1 "$RESULTS_DIR/$server.log")"
        failed=$(( failed + 1 ))
    fi
done
echo "Done: $(( ${#SERVERS[@]} - failed )) ok, $failed failed"
(( failed == 0 ))
