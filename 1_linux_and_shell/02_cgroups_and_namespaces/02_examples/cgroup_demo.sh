#!/usr/bin/env bash
# Демонстрация cgroups v2 и namespaces
# Требует: root или sudo

echo "=== cgroups v2 ==="

# Проверить версию cgroups
if mount | grep -q cgroup2; then
    echo "cgroups v2 активен"
else
    echo "cgroups v1 или смешанный режим"
fi

# Посмотреть cgroup текущего процесса
echo "Текущий cgroup:"
cat /proc/$$/cgroup

# Посмотреть cgroup Docker контейнера
if docker ps -q 2>/dev/null | head -1 | grep -q .; then
    CID=$(docker ps -q | head -1)
    CPID=$(docker inspect "$CID" --format '{{.State.Pid}}')
    echo -e "\nDocker контейнер $CID, PID $CPID:"
    cat /proc/"$CPID"/cgroup 2>/dev/null | head -3
    echo "Memory limit:"
    cat /sys/fs/cgroup/system.slice/docker-"$CID".scope/memory.max 2>/dev/null \
        || echo "(недоступно)"
fi

echo -e "\n=== namespaces ==="
echo "Namespaces текущего процесса:"
ls -la /proc/$$/ns/

echo -e "\nДемонстрация PID namespace (unshare):"
echo "Текущий PID: $$"
echo "PID внутри нового namespace:"
sudo unshare --pid --fork --mount-proc bash -c 'echo "  PID=$$, process count=$(ps aux | wc -l)"' 2>/dev/null \
    || echo "  (требуется root)"
