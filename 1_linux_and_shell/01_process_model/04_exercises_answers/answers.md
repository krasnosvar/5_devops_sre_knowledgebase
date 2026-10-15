# Ответы — Process Model

Упражнения 01-03 дополнительно разобраны готовыми Python-программами
в этой директории:
[01_fork_exec.py](./01_fork_exec.py), [02_zombie.py](./02_zombie.py),
[03_graceful_shutdown.py](./03_graceful_shutdown.py). Выводы ниже
приблизительные: PID у вас будут другими.

## Упражнение 01 — fork и exec на практике

```bash
bash -c 'echo child PID=$$; sleep 60' &
CHILD_PID=$!
echo "shell PID=$$, child=$CHILD_PID"
pstree -p $$
kill $CHILD_PID

python3 01_fork_exec.py
```

Ожидаемый вывод (примерно так):

```text
child PID=48211
shell PID=47990, child=48211
bash(47990)─┬─pstree(48230)
            └─sleep(48211)
Parent PID: 48302
Parent spawned child PID: 48303
Child PID: 48303, Parent: 48302
Child reaped, no zombie
exec process PID=48304
```

Почему так: shell делает `fork()`, потомок — `exec()` нового образа.
Bash выполняет последнюю команду `-c` через `exec`, поэтому в дереве под
тем же PID 48211 уже `sleep`, а не `bash`. Если взять `$$` в двойные
кавычки, его раскроет родительский shell и PID будет «чужой».

## Упражнение 02 — Zombie процесс

```bash
python3 zombie.py &          # программа из текста упражнения
sleep 3
ps -eo pid,ppid,stat,cmd | grep -E 'Z|defunct' | grep -v grep

python3 02_zombie.py         # как zombie не допускать
```

Ожидаемый вывод (примерно так):

```text
Parent PID: 50110, child PID: 50111
Child 50111 exiting
  50111   50110 Z+   [python3] <defunct>
[child] PID=50140 exiting
[parent] Child 50140 reaped cleanly
[child] PID=50141 exiting (SIGCHLD will reap me)
[handler] Reaped child 50141
[parent] Done — SIGCHLD handler reaped child automatically
```

Почему так: завершившийся потомок остаётся в таблице процессов (статус `Z`)
с кодом выхода, пока родитель не вызовет `wait()`. `kill -9` zombie не
поможет — он уже мёртв; исчезнет, когда родитель сделает `wait()` или сам
завершится (тогда потомка «усыновит» PID 1 и пожнёт его).

## Упражнение 03 — Сигналы: SIGTERM vs SIGKILL

```bash
python3 graceful.py &
PID=$!
sleep 1
kill -SIGTERM $PID
wait $PID; echo "Exit code: $?"

python3 graceful.py &
PID=$!
sleep 1
kill -SIGKILL $PID
wait $PID; echo "Exit code: $?"
```

Ожидаемый вывод (примерно так):

```text
PID: 51001, waiting for signals...
Received SIGTERM, cleaning up...
Cleanup done, exiting gracefully
Exit code: 0
PID: 51020, waiting for signals...
Exit code: 137
```

Почему так: SIGTERM можно перехватить — сработал обработчик и
`sys.exit(0)`. SIGKILL перехватить нельзя: ядро убивает процесс сразу,
cleanup не выполняется, shell сообщает 128 + 9 = 137. Расширенная версия
с ожиданием in-flight запросов — [03_graceful_shutdown.py](./03_graceful_shutdown.py).

## Упражнение 04 — /proc — читать информацию о процессе

```bash
sleep 3600 &
PID=$!
grep -E 'Name|^Pid|PPid|State|VmRSS' /proc/$PID/status
tr '\0' ' ' < /proc/$PID/cmdline; echo
ls /proc/$PID/fd | wc -l
head -3 /proc/$PID/maps
ps -p $PID -o pid,ppid,stat,vsz,rss,cmd
kill $PID
```

Ожидаемый вывод (примерно так):

```text
Name:	sleep
State:	S (sleeping)
Pid:	52007
PPid:	47990
VmRSS:	    1920 kB
sleep 3600
3
55d1c2a4e000-55d1c2a50000 r--p 00000000 fd:00 1311 /usr/bin/sleep
...
    PID    PPID STAT    VSZ   RSS CMD
  52007   47990 S      5584  1920 sleep 3600
```

Почему так: `ps` сам ничего не знает — он читает те же файлы `/proc/<pid>/`.
`cmdline` разделён нулевыми байтами, поэтому нужен `tr`. Три fd — это
унаследованные stdin/stdout/stderr. `VmRSS` в `status` совпадает с `RSS`
в `ps` (оба в килобайтах), а `VSZ` больше, потому что учитывает всю
отображённую, но не обязательно загруженную в RAM память.
