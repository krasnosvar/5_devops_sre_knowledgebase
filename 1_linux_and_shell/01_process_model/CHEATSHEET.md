# Процессы, память и сигналы — шпаргалка

Подробности и объяснения — в [process_model.md](./01_theory/process_model.md).
⚠️ — опасная команда или частая ловушка.

## Смотреть процессы

| Задача | Команда |
| :--- | :--- |
| Все процессы с родителем и состоянием | `ps -eo pid,ppid,stat,ni,rss,vsz,etime,comm` |
| Топ по памяти / по CPU | `ps -eo pid,rss,comm --sort=-rss \| head`<br>`ps -eo pid,%cpu,comm --sort=-%cpu \| head` |
| Дерево процессов | `ps -ef --forest` или `pstree -p` |
| Потоки (LWP) процесса | `ps -eLf -p <PID>` или `top -H -p <PID>` |
| Найти PID по имени / командной строке | `pgrep -a nginx` / `pgrep -af 'java.*app.jar'` |
| CPU / память / I/O по процессам раз в секунду | `pidstat -u 1` / `pidstat -r 1` / `pidstat -d 1` |
| Командная строка и окружение | `tr '\0' ' ' < /proc/<PID>/cmdline`<br>`tr '\0' '\n' < /proc/<PID>/environ` |
| Состояние, потоки, память, сигналы | `cat /proc/<PID>/status` |
| Карта памяти процесса | `pmap -x <PID>`, `cat /proc/<PID>/maps` |
| RSS и PSS одной строкой | `grep -E '^(Rss\|Pss):' /proc/<PID>/smaps_rollup` |
| Лимиты процесса | `cat /proc/<PID>/limits` или `prlimit --pid <PID>` |

## Колонка STAT / S

| Код | Состояние | Заметка |
| :--- | :--- | :--- |
| `R` | Running / Runnable | на CPU или в очереди |
| `S` | Interruptible sleep | ждёт событие, сигналы работают |
| `D` | Uninterruptible sleep | ⚠️ ждёт I/O в ядре, `SIGKILL` не действует |
| `Z` | Zombie | ⚠️ уже мёртв, ждёт `wait()` от родителя |
| `T` | Stopped | `SIGSTOP`/`Ctrl+Z`, продолжить: `kill -CONT` |
| `s` `l` `+` `<` `N` | лидер сессии / многопоточный / foreground / высокий / низкий приоритет | |

## Память процесса

| Метрика | Смысл |
| :--- | :--- |
| VSZ / VIRT | всё запрошенное адресное пространство, не физическая RAM |
| RSS / RES | физически загруженные страницы, включая общие `.so` |
| PSS | RSS с долей общих страниц, делённой на число процессов — честнее при суммировании |
| Text / Data+BSS / Heap ↑ / mmap / Stack ↓ | сегменты адресного пространства |

⚠️ Сумма RSS всех процессов больше реально занятой RAM — общие страницы
считаются многократно.

## Сигналы

| Сигнал | № | Ловится? | Типичное использование |
| :--- | :--- | :--- | :--- |
| `SIGHUP` | 1 | да | перечитать конфиг (nginx, sshd) |
| `SIGINT` | 2 | да | `Ctrl+C` |
| `SIGKILL` | 9 | ⚠️ нет | безусловное убийство ядром |
| `SIGTERM` | 15 | да | graceful shutdown (по умолчанию у `kill`) |
| `SIGCHLD` | 17 | да | потомок завершился |
| `SIGSTOP` / `SIGCONT` | 19 / 18 | нет / да | заморозить / продолжить |

| Задача | Команда |
| :--- | :--- |
| Мягко остановить | `kill <PID>` (= `kill -TERM`) |
| Перечитать конфиг | `kill -HUP <PID>` |
| Убить ⚠️ без cleanup | `kill -9 <PID>` |
| По имени | `pkill -TERM -f 'worker.py'` |
| Список сигналов | `kill -l` |
| Ограничить время команды | `timeout -k 5 30 <cmd>` (TERM через 30 с, KILL ещё через 5) |

| Exit code | Смысл |
| :--- | :--- |
| `128 + N` | убит сигналом N: `137` = SIGKILL (часто OOM), `143` = SIGTERM |
| `126` / `127` | не исполняемый / команда не найдена |

## Zombie и orphan

| Задача | Команда |
| :--- | :--- |
| Найти зомби и их родителей | `ps -eo pid,ppid,stat,comm \| awk '$3 ~ /Z/'` |
| Попросить родителя сделать `wait()` | `kill -CHLD <PPID>` |
| Убрать зомби ⚠️ убивает родителя | `kill <PPID>` — зомби усыновит PID 1 и очистит |

## OOM Killer

| Задача | Команда |
| :--- | :--- |
| Кого убил OOM | `journalctl -k \| grep -i -E 'out of memory\|oom-kill'` или `dmesg -T \| grep -i oom` |
| Текущий балл процесса | `cat /proc/<PID>/oom_score` |
| Защитить процесс ⚠️ root | `echo -1000 \| sudo tee /proc/<PID>/oom_score_adj` |
| То же для systemd-сервиса | `OOMScoreAdjust=-1000` в `[Service]` |

| `oom_score_adj` | Где встречается |
| :--- | :--- |
| `-1000` | никогда не убивать |
| `-997` | k8s Pod QoS `Guaranteed` |
| `2..999` | k8s `Burstable` (зависит от requests) |
| `1000` | k8s `BestEffort` — убивают первым |

## Приоритеты CPU

| Задача | Команда |
| :--- | :--- |
| Запустить с низким приоритетом | `nice -n 10 tar -czf backup.tgz /var/log` |
| Изменить у запущенного | `renice -n 5 -p <PID>` (отрицательные — ⚠️ только root) |
| Низкий приоритет I/O | `ionice -c3 <cmd>` (idle) или `ionice -c2 -n7 <cmd>` |
| Политика планировщика | `chrt -p <PID>` |

| Значение | Смысл |
| :--- | :--- |
| nice `-20 … +19` | `-20` — максимальный приоритет, по умолчанию `0` |
| `PR = 20 + NI` | в `top` для обычных процессов (`rt` — real-time) |

> Проверка: `ps`, `pidstat`, `prlimit`, `pmap`, `smaps_rollup`, `chrt`,
> `ionice`, `kill -l`, `timeout` запущены локально (procps-ng, sysstat 12.x,
> util-linux 2.41, Fedora 44, kernel 7.2); не проверено: `renice` с
> отрицательным значением и запись в `oom_score_adj` (нужен root).
