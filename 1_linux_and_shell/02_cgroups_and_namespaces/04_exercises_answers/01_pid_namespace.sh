#!/usr/bin/env bash
# Ответ: упражнение 01 — PID namespace через unshare
# Демонстрирует: изолированное дерево процессов

echo "=== Хостовые процессы (видим всё) ==="
echo "Текущий PID: $$"
echo "Всего процессов: $(ps aux | wc -l)"

echo -e "\n=== Новый PID namespace через unshare ==="
# unshare создаёт новый PID namespace
# --fork: нужен чтобы bash стал PID 1 в новом namespace
# --mount-proc: монтирует новый /proc для нового namespace
sudo unshare --pid --fork --mount-proc bash -c '
    echo "Мой PID в новом namespace: $$"
    echo "Всего процессов видно: $(ps aux | wc -l)"
    echo "Список процессов:"
    ps aux
    echo ""
    echo "PID 1 в этом namespace — это bash, а не systemd!"
'

echo -e "\n=== Namespace контейнера Docker ==="
if docker ps -q 2>/dev/null | head -1 | grep -q .; then
    CID=$(docker ps -q | head -1)
    HOST_PID=$(docker inspect "$CID" --format '{{.State.Pid}}')
    echo "Контейнер $CID: host PID=$HOST_PID"
    echo "Его namespaces:"
    ls -la /proc/"$HOST_PID"/ns/ 2>/dev/null | grep -v '^total'

    echo -e "\nPID внутри контейнера:"
    docker exec "$CID" ps aux 2>/dev/null | head -5

    echo -e "\nТот же процесс снаружи — другой PID:"
    cat /proc/"$HOST_PID"/status 2>/dev/null | grep -E "^(Name|Pid|NSpid):"
fi
