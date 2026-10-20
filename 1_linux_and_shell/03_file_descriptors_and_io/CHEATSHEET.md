# Файловые дескрипторы и I/O — шпаргалка

Подробности и объяснения — в [fd_and_io.md](./01_theory/fd_and_io.md).
⚠️ — опасная команда или частая ловушка.

## Дескрипторы процесса

| Задача | Команда |
| :--- | :--- |
| Сколько fd открыто | `ls /proc/<PID>/fd \| wc -l` |
| Куда указывают fd | `ls -l /proc/<PID>/fd` (`socket:[12345]`, `pipe:[…]`, путь) |
| Offset и флаги конкретного fd | `cat /proc/<PID>/fdinfo/<FD>` |
| Все открытые файлы процесса | `lsof -p <PID>` |
| Кто держит файл / каталог | `lsof /var/log/app.log`, `fuser -v /mnt/data` |
| Кто слушает порт | `lsof -nP -iTCP:8080 -sTCP:LISTEN` (или `ss -tlnp`) |
| Удалённые, но открытые файлы | `lsof +L1` |
| Лимит fd процесса | `grep 'open files' /proc/<PID>/limits` |
| Лимит текущего shell | `ulimit -Sn` (soft) / `ulimit -Hn` (hard) |
| Изменить лимит у работающего процесса | `sudo prlimit --pid <PID> --nofile=65535:65535` |
| Открыто fd во всей системе | `cat /proc/sys/fs/file-nr` (открыто, 0, максимум) |

## Где задаётся лимит открытых файлов

| Где | Как | Для кого |
| :--- | :--- | :--- |
| systemd-сервис | `LimitNOFILE=65535` в `[Service]` + `daemon-reload` + restart | демоны ⚠️ `limits.conf` на них не действует |
| Логин-сессии | `/etc/security/limits.conf`: `app soft nofile 65535` (через `pam_limits`) | SSH/консоль |
| Текущий shell | `ulimit -n 65535` (не выше hard) | этот shell и потомки |
| Потолок на процесс | `fs.nr_open` | максимум для `nofile` |
| Вся система | `fs.file-max` | сумма всех fd |
| Docker | `--ulimit nofile=65535:65535` | контейнер |

| Значение | Смысл |
| :--- | :--- |
| `1024` | классический soft-лимит по умолчанию, мало для серверов |
| `EMFILE` | «Too many open files» — исчерпан лимит процесса |
| `ENFILE` | исчерпан системный `fs.file-max` |

## Перенаправления в shell

| Конструкция | Что делает |
| :--- | :--- |
| `cmd > f` / `cmd >> f` | stdout в файл (перезапись / дописать) |
| `cmd 2> err.log` | stderr в файл |
| `cmd > f 2>&1` или `cmd &> f` | оба потока в файл |
| `cmd 2>&1 > f` | ⚠️ stderr на экран, stdout в файл — порядок важен |
| `cmd > /dev/null 2>&1` | заглушить всё |
| `cmd 2>&1 \| tee log` | в файл и на экран |
| `exec 3> out.txt; echo hi >&3; exec 3>&-` | открыть / писать / закрыть свой fd 3 |
| `cmd < f` | stdin из файла |
| `diff <(sort a) <(sort b)` | process substitution: вывод как файл `/dev/fd/N` |
| `stdbuf -oL cmd \| grep x` | построчная буферизация stdout в пайпе |

## Модели I/O и мультиплексирование

| Модель | Поведение | Где |
| :--- | :--- | :--- |
| Blocking | `read()` усыпляет поток до данных | простые программы, поток на клиента |
| Non-blocking | `read()` сразу `EAGAIN`/`EWOULDBLOCK` | вместе с epoll |
| `select()` / `poll()` | весь список fd на каждый вызов, O(N); `select` ≤ 1024 fd | легаси |
| `epoll` | регистрация один раз (`epoll_ctl`), `epoll_wait` отдаёт только готовые | nginx, Redis, Node.js, Go |
| `io_uring` | кольца SQ/CQ в общей памяти, пачки запросов | БД, высокий IOPS |

## Сокеты

| Задача | Команда |
| :--- | :--- |
| Слушающие сокеты с процессом | `ss -tlnp` |
| Очередь accept: Recv-Q / Send-Q | `ss -lnt 'sport = :80'` (LISTEN: Recv-Q — ждут `accept()`, Send-Q — backlog) |
| Переполнения backlog | `nstat -az TcpExtListenOverflows TcpExtListenDrops` |
| Потолок backlog | `sysctl net.core.somaxconn` (дефолт `4096` с ядра 5.4) |
| UNIX-сокеты | `ss -xlp` |
| Syscalls сокетов приложения | `strace -f -e trace=network -p <PID>` ⚠️ замедляет |

| Цикл серверного TCP-сокета | |
| :--- | :--- |
| `socket()` → `bind()` → `listen(backlog)` → `accept()` | `accept()` возвращает **новый** fd на клиента |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| `Too many open files` | `/proc/<PID>/limits`, `ls /proc/<PID>/fd \| wc -l`, утечка — растёт ли число |
| Логи «не появляются» в пайпе | буферизация stdout → `stdbuf -oL`, `PYTHONUNBUFFERED=1` |
| Клиенты ловят таймауты connect | `ss -lnt` Recv-Q ≥ Send-Q, `TcpExtListenOverflows` |
| `df` полный, `du` нет | `lsof +L1` — удалённый, но открытый файл |

> Проверка: `/proc/<PID>/fd`, `fdinfo`, `file-nr`, `nr_open`, `somaxconn`,
> `ulimit`, `lsof -h`, `stdbuf`, `ss`, `nstat` — локально (lsof 4.99,
> iproute2 6.x, kernel 7.2); не проверено: `prlimit --pid` на чужом
> процессе (нужен root), `docker --ulimit` не запускался.
