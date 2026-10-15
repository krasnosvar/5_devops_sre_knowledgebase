#!/usr/bin/env bash
# Ответ: упражнение 04 — мониторинг заполненности дисков с алертом в лог.
# Использование: bash 04_disk_monitor.sh [LOG_FILE]
#   (по умолчанию ./disk_monitor.log; переопределяется переменными
#    THRESHOLD, INTERVAL, LOCK_FILE). Остановка — kill <pid> или Ctrl+C.
set -euo pipefail

THRESHOLD=${THRESHOLD:-80}       # порог заполненности, %
INTERVAL=${INTERVAL:-30}         # период проверки, секунд
LOG_FILE=${1:-./disk_monitor.log}
LOCK_FILE=${LOCK_FILE:-/tmp/disk_monitor.lock}

log() { echo "$(date '+%Y-%m-%dT%H:%M:%S%z') $*" >>"$LOG_FILE"; }

# Lockfile через flock: блокировку держит открытый fd 9, ядро снимет её само,
# даже если процесс убит SIGKILL — "протухших" lockfile не бывает
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    echo "ERROR: уже запущен другой экземпляр (lock: $LOCK_FILE)" >&2
    exit 1
fi

cleanup() {
    log "INFO stopped by signal, pid=$$"
    rm -f "$LOCK_FILE"
    exit 0
}
trap cleanup TERM INT

check_disks() {
    local mount usage
    # -P: POSIX-формат, одна строка на ФС; -x: пропустить псевдо-ФС
    while read -r mount usage; do
        usage=${usage%\%}
        if (( usage > THRESHOLD )); then
            log "ALERT $mount usage ${usage}% > ${THRESHOLD}%"
        fi
    done < <(df -P -x tmpfs -x devtmpfs -x overlay -x squashfs -x efivarfs \
               | awk 'NR > 1 { print $6, $5 }')
}

log "INFO started, pid=$$, threshold=${THRESHOLD}%, interval=${INTERVAL}s"
while true; do
    check_disks
    # sleep в фоне + wait: trap срабатывает сразу, а не после sleep
    sleep "$INTERVAL" &
    wait $!
done
