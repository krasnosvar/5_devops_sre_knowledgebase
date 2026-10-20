# Производительность и eBPF — шпаргалка

Подробности и объяснения — в
[ebpf_and_observability.md](./01_theory/ebpf_and_observability.md).
Методика разбора инцидентов — в [11_troubleshooting](../11_troubleshooting/).
⚠️ — опасная команда или частая ловушка.

## Чем трассировать

| Инструмент | Механизм | Оверхед | Когда |
| :--- | :--- | :--- | :--- |
| `strace` | `ptrace`, стоп на каждом syscall | ⚠️ высокий (кратное замедление) | dev/стейджинг, редкие syscalls, `-c` для сводки |
| `perf` | сэмплирование PMC / таймером | низкий при `-F 99` | где горит CPU, flame graph |
| `bpftrace` | eBPF, агрегация в ядре (maps) | низкий | ad-hoc вопросы к ядру и приложению в проде |
| BCC tools | готовые eBPF-утилиты | низкий | типовые вопросы: exec, open, latency, retrans |

## Типы хуков eBPF

| Хук | Что | Стабильность |
| :--- | :--- | :--- |
| `tracepoint:` | статические точки ядра | стабильны между версиями |
| `kprobe:` / `kretprobe:` | вход/выход любой функции ядра | ⚠️ зависят от версии, функция может быть inline |
| `uprobe:` / `uretprobe:` | функции в user-space бинарнике | зависят от символов бинарника |
| `profile:hz:99` | таймер на всех CPU | — |
| XDP | драйвер NIC, до `sk_buff` | `XDP_DROP`, `XDP_PASS`, `XDP_TX`, `XDP_REDIRECT` |

## bpftrace: однострочники

| Задача | Команда |
| :--- | :--- |
| Список проб | `sudo bpftrace -l 'tracepoint:syscalls:sys_enter_open*'` |
| Кто какие файлы открывает | `sudo bpftrace -e 'tracepoint:syscalls:sys_enter_openat { printf("%s %s\n", comm, str(args.filename)); }'` |
| Новые процессы | `sudo bpftrace -e 'tracepoint:syscalls:sys_enter_execve { printf("%s -> %s\n", comm, str(args.filename)); }'` |
| Syscalls по процессам | `sudo bpftrace -e 'tracepoint:raw_syscalls:sys_enter { @[comm] = count(); }'` |
| Латентность `vfs_read`, гистограмма мкс | `sudo bpftrace -e 'kprobe:vfs_read { @s[tid] = nsecs; } kretprobe:vfs_read /@s[tid]/ { @us = hist((nsecs - @s[tid]) / 1000); delete(@s[tid]); }'` |
| Стек ретрансмитов TCP | `sudo bpftrace -e 'kprobe:tcp_retransmit_skb { @[kstack] = count(); }'` |
| CPU-профиль процесса | `sudo bpftrace -e 'profile:hz:99 /pid == 1234/ { @[ustack] = count(); }'` |

⚠️ Старые примеры с `args->filename` — синтаксис до bpftrace 0.20; сейчас
`args.filename`.

## BCC tools

Пакет `bcc-tools` (RHEL: `/usr/share/bcc/tools/`) или `bpfcc-tools`
(Debian/Ubuntu: суффикс `-bpfcc`, например `execsnoop-bpfcc`).

| Утилита | Отвечает на вопрос |
| :--- | :--- |
| `execsnoop` | какие короткоживущие процессы запускаются |
| `opensnoop` | какие файлы открываются (и с какой ошибкой) |
| `biolatency` | гистограмма латентности блочного I/O |
| `biosnoop` | каждый I/O: процесс, диск, латентность |
| `runqlat` | сколько задачи ждут CPU в runqueue |
| `tcpretrans` | ретрансмиты TCP с адресами |
| `tcpconnect` / `tcpaccept` | исходящие / входящие соединения |
| `offcputime` | где потоки спят (блокировки, I/O) |
| `profile` | сэмплирующий CPU-профиль |

## perf

| Задача | Команда |
| :--- | :--- |
| Топ функций в реальном времени | `sudo perf top` (процесс: `-p <PID>`) |
| Счётчики (IPC, cache misses) | `sudo perf stat -p <PID> -- sleep 10` |
| Записать профиль со стеками | `sudo perf record -F 99 -g -p <PID> -- sleep 30` |
| Вся система | `sudo perf record -F 99 -a -g -- sleep 30` |
| Отчёт | `sudo perf report --stdio` |
| Flame graph | `sudo perf script \| stackcollapse-perf.pl \| flamegraph.pl > cpu.svg` |
| Доступ без root | `kernel.perf_event_paranoid` (≤ 1 — больше разрешено) |

⚠️ Без frame pointers / debuginfo стеки обрываются: `perf record
--call-graph dwarf` или сборка с `-fno-omit-frame-pointer`.

## strace: если очень нужно

| Задача | Команда |
| :--- | :--- |
| Сводка по syscalls | `strace -c -f -p <PID>` (Ctrl+C — итог) |
| Время каждого вызова | `strace -f -tt -T -p <PID>` |
| Только сеть / файлы | `strace -f -e trace=network,file -p <PID>` |
| Только неудачные вызовы | `strace -f -Z -p <PID>` (успешные: `-z`) |
| Запустить под трассировкой | `strace -f -o trace.log <cmd>` |

## Состояние eBPF в системе

| Задача | Команда |
| :--- | :--- |
| Загруженные программы / maps | `sudo bpftool prog list` / `sudo bpftool map list` |
| XDP на интерфейсах | `ip link` (`xdp`/`xdpgeneric` в выводе), `sudo bpftool net` |
| JIT включён | `sysctl net.core.bpf_jit_enable` (`1`) |
| BTF ядра (CO-RE) | `ls /sys/kernel/btf/vmlinux` |

| Значение | Смысл |
| :--- | :--- |
| 1 млн инструкций | лимит верификатора на программу (раньше 4096) |
| bounded loops | с ядра 5.3; бесконечные циклы запрещены |
| `io_uring` | SQ/CQ в общей памяти; без syscalls — только в режиме SQPOLL |

> Проверка: `strace` флаги (`-c`, `-tt`, `-T`, `-z/-Z`, `-e trace=`)
> сверены с `strace --help` (strace 7.2); символы `vfs_read`,
> `tcp_retransmit_skb` есть в `/proc/kallsyms` (kernel 7.2),
> `bpf_jit_enable`, BTF — проверены; не проверено: однострочники
> bpftrace, `perf`, BCC, `bpftool` (не установлены; `bpftrace --dry-run` в
> непривилегированном контейнере не смог загрузить пробы) — синтаксис по
> документации bpftrace ≥ 0.20.
