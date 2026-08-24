# Файловые дескрипторы и I/O

## Всё есть файл

В Linux почти всё представлено как файл: обычные файлы, директории,
сокеты, pipes, устройства, `/proc` записи. Одинаковый интерфейс
`open/read/write/close` для всего.

## Файловый дескриптор (fd)

fd — целое число, указывающее на запись в таблице открытых файлов процесса.

```
Процесс                  Системная таблица файлов
─────────                ───────────────────────────
fd 0  ──────────────────► /dev/pts/0 (stdin, терминал)
fd 1  ──────────────────► /dev/pts/0 (stdout, терминал)
fd 2  ──────────────────► /dev/pts/0 (stderr, терминал)
fd 3  ──────────────────► /var/log/app.log (открытый файл)
fd 4  ──────────────────► socket:[12345] (сетевое соединение)
```

```bash
# посмотреть открытые fd процесса
ls -la /proc/1234/fd/
lsof -p 1234              # подробнее: имена файлов, режим доступа

# сколько fd открыто (важно для long-running сервисов)
ls /proc/1234/fd | wc -l

# лимиты fd
ulimit -n                 # лимит для текущего shell
cat /proc/sys/fs/file-max # общесистемный лимит

# изменить лимит (в /etc/security/limits.conf для постоянно)
ulimit -n 65536
```

## stdin, stdout, stderr

| fd | Имя | Назначение |
|----|-----|-----------|
| 0 | stdin | Ввод (по умолчанию: клавиатура) |
| 1 | stdout | Обычный вывод |
| 2 | stderr | Ошибки и диагностика |

```bash
# перенаправление stdout
command > file.txt          # перезаписать
command >> file.txt         # добавить

# перенаправление stderr
command 2> errors.txt

# оба потока в один файл
command > all.txt 2>&1
command &> all.txt          # сокращение

# выбросить вывод
command > /dev/null 2>&1

# stdin из файла
command < input.txt

# здесь строка (heredoc)
command <<EOF
multi-line
input
EOF
```

## Pipes — соединение процессов

Pipe (`|`) соединяет stdout одного процесса со stdin следующего.
Реализован как буфер в памяти ядра (по умолчанию 64KB в Linux).

```bash
cat /var/log/nginx/access.log | grep "POST" | awk '{print $1}' | sort | uniq -c | sort -rn

# tee — и в файл, и в следующий pipe
command | tee /tmp/debug.log | grep ERROR

# process substitution (bash) — pipe как файл
diff <(ssh server1 cat /etc/hosts) <(ssh server2 cat /etc/hosts)

# named pipe (FIFO) — pipe между несвязанными процессами
mkfifo /tmp/mypipe
producer > /tmp/mypipe &
consumer < /tmp/mypipe
```

## Буферизация — почему вывод "залипает"

**Line-buffered**: stdout сбрасывается при каждом `\n` (когда подключён терминал).
**Block-buffered**: stdout сбрасывается блоками ~8KB (когда перенаправлен в pipe/файл).
**Unbuffered**: stderr всегда сразу.

```bash
# проблема: вывод не появляется в pipe пока буфер не заполнится
python script.py | grep pattern   # долгое ожидание первых строк

# решение: отключить буферизацию
python -u script.py | grep pattern       # -u = unbuffered
PYTHONUNBUFFERED=1 python script.py | grep pattern

# stdbuf — универсальный инструмент
stdbuf -oL command | grep pattern        # line-buffered stdout
```

## Утечки fd в контейнерах

Если приложение не закрывает fd (утечка), /proc/PID/fd растёт.
В k8s это проявляется как постепенная деградация пода.

```bash
# мониторинг fd count
watch -n 1 'ls /proc/$(pgrep myapp)/fd | wc -l'

# lsof для поиска незакрытых файлов
lsof -p $(pgrep myapp) | grep -v "REG\|DIR" | head -20
```
