#!/usr/bin/env bash
# Демонстрация файловых дескрипторов, pipes, перенаправления

echo "=== Файловые дескрипторы текущего shell ==="
echo "PID: $$"
ls -la /proc/$$/fd/
echo "Количество открытых FD: $(ls /proc/$$/fd | wc -l)"

echo -e "\n=== Перенаправление ==="
# stdout в файл
echo "Hello stdout" > /tmp/stdout.txt
# stderr отдельно
ls /nonexistent 2>/tmp/stderr.txt || true
# оба вместе
echo "Both streams" > /tmp/both.txt 2>&1

echo "stdout.txt: $(cat /tmp/stdout.txt)"
echo "stderr.txt: $(cat /tmp/stderr.txt)"

echo -e "\n=== Named pipe (FIFO) ==="
FIFO=/tmp/demo_fifo
mkfifo "$FIFO"
echo "Producer sending data..." > "$FIFO" &
PRODUCER=$!
RESULT=$(cat "$FIFO")
echo "Consumer received: $RESULT"
wait $PRODUCER 2>/dev/null || true
rm -f "$FIFO"

echo -e "\n=== Буферизация: почему вывод 'залипает' в pipe ==="
# stdbuf отключает буферизацию
echo "Без stdbuf (block-buffered):"
python3 -c "
import sys, time
for i in range(3):
    sys.stdout.write(f'line {i}\n')
    time.sleep(0.1)
" | cat

echo "С stdbuf -oL (line-buffered):"
stdbuf -oL python3 -c "
import sys, time
for i in range(3):
    sys.stdout.write(f'line {i}\n')
    sys.stdout.flush()
    time.sleep(0.1)
" | cat

echo -e "\n=== lsof: открытые файлы процесса ==="
# Открыть файл, посмотреть в lsof
exec 5>/tmp/test_fd
lsof -p $$ 2>/dev/null | grep test_fd || echo "(lsof недоступен)"
exec 5>&-   # закрыть FD 5
rm -f /tmp/test_fd /tmp/stdout.txt /tmp/stderr.txt /tmp/both.txt
