# Производительность, кэширование и масштабирование — шпаргалка

Подробности и объяснения — в
[01_bottlenecks_and_profiling_methodology.md](./01_theory/01_bottlenecks_and_profiling_methodology.md),
[02_caching_levels_and_patterns.md](./01_theory/02_caching_levels_and_patterns.md)
и
[03_scaling_high_load_systems.md](./01_theory/03_scaling_high_load_systems.md).
⚠️ — опасная команда или частая ловушка.

## Математические законы производительности

| Закон | Формула | Практический смысл для SRE |
| :--- | :--- | :--- |
| Закон Литтла (Little's Law) | $L = \lambda \times W$ | Число активных запросов/соединений = $\text{RPS} \times \text{Latency}$ (при росте задержки в 10x пулы забиваются в 10x) |
| Закон Амдала (Amdahl's Law) | $S(N) = \frac{1}{\alpha + (1-\alpha)/N}$ | Последовательная доля $\alpha$ (общая БД/лок) жёстко ограничивает выигрыш от добавления реплик |
| Закон очередей Кингмана | $W_q \propto \frac{\rho}{1 - \rho}$ | ⚠️ Выше **70–75%** утилизации ($\rho$) время ожидания в очереди растёт экспоненциально |
| Эффективная задержка кэша | $T_{\text{eff}} = H \cdot T_c + (1-H)(T_c + T_{db})$ | Рост Hit Ratio с 95% до 99% снижает нагрузку на БД **в 5 раз** |

## Топология и паттерны кэширования

| Уровень / Паттерн | Где живёт / Как работает | Главный нюанс |
| :--- | :--- | :--- |
| L0 Browser / L1 CDN | `Cache-Control`, `ETag`, Edge PoP | Разгружает сеть и Origin до входа в ДЦ |
| L2 Reverse Proxy | nginx `proxy_cache`, Varnish | `proxy_cache_use_stale updating` спасает от stampede |
| L3 In-Process (L1 app) | Локальная RAM процесса (`~100 нс`) | В 10 000x быстрее Redis, но ⚠️ рассинхрон между репликами |
| L4 Distributed (L2 app) | Redis, KeyDB, Memcached (`~0.5–2 мс`) | Единое состояние для всех подов, переживает рестарты |
| **Cache-Aside** | App читает кэш → при Miss читает БД → пишет в кэш | При записи в БД делать **`DEL` ключа**, а не `SET` (иначе гонка!) |
| **Write-Behind** | Запись в кэш → асинхронный сброс батчами в БД | Спасает от 500k RPS счётчиков/лайков, но ⚠️ риск потери при сбое кэша |

## Четыре аномалии кэша и их лечение

| Аномалия | Что происходит | Чем лечить |
| :--- | :--- | :--- |
| **Cache Stampede (Thundering Herd)** | Горячий ключ истёк → тысячи потоков одновременно бьют в БД | `singleflight` (request coalescing), распределённый лок, фоновый прогрев до TTL |
| **Cache Avalanche (Лавина)** | Миллион ключей с одинаковым TTL истекли в одну секунду | **TTL Jitter**: $\text{TTL} = \text{base} + \text{random}(-\Delta, +\Delta)$ |
| **Cache Penetration (Пробивание)** | Запросы за несуществующим `id=-1` идут мимо кэша в БД | Negative Caching (`NULL` на 30–60 с) + **Bloom Filter** перед кэшем |
| **Hot Key Problem** | 1 суперпопулярный ключ перегружает 1 ядро/шард Redis | Кэшировать в L3 (память подов) на 1–5 с или размножить ключ с суффиксами `key:1..N` |

## Горизонтальное масштабирование: что выбрать

| Нагрузка / Уровень | Механизм | Скорость реакции и особенности |
| :--- | :--- | :--- |
| Stateless HTTP/gRPC | Kubernetes HPA (CPU / custom RPS) | Секунды (если есть свободное место на нодах) |
| Очереди (Kafka, RabbitMQ, SQS) | KEDA (по лагу партиций / длине очереди) | Секунды; умеет масштабировать `0 ↔ N` |
| Одиночный тяжёлый сервис | VPA (Vertical Pod Autoscaler) | ⚠️ Не включать вместе с HPA по CPU/Memory! |
| Добавление нод кластера | Karpenter / Cluster Autoscaler | Десятки секунд (Karpenter) — минуты (CA); буфер через **Overprovisioning** |
| Без Kubernetes (VM Fleet) | LB + ASG/MIG + Golden Image (`Packer`) | Минуты (boot ОС, `cloud-init`, health check) |
| Защита БД от Connection Storm | PgBouncer (`transaction pooling`), ProxySQL | Держит фиксированное число соединений к БД при любом числе подов |

## Команды диагностики узких мест, лимитов ОС и Redis

| Что проверить | Команда / параметр |
| :--- | :--- |
| Очередь CPU, контекст-свитчи, swap | `vmstat 1 5` |
| Давление на ресурсы (Linux PSI) и CPU throttling | `cat /proc/pressure/{cpu,memory,io}`, `grep throttled /sys/fs/cgroup/cpu.stat` |
| Утилизация и очередь к дискам (`aqu-sz`, `await`) | `iostat -xz 1 3` |
| Лимит файловых дескрипторов процесса | `ulimit -n`, `grep 'open files' /proc/<pid>/limits`, `ls /proc/<pid>/fd \| wc -l` |
| Переполнение `accept()` очереди сокета | `ss -ltn` (`Recv-Q` у `Send-Q`), `nstat -az TcpExtListenOverflows TcpExtListenDrops` |
| Переполнение таблицы `conntrack` | `sysctl net.netfilter.nf_conntrack_count net.netfilter.nf_conntrack_max` |
| Асинхронное удаление гигантского ключа в Redis | `UNLINK <key>` (вместо блокирующего `DEL`), обход ключей через `SCAN` (не `KEYS *`!) |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| На ноде CPU 30%, но приложение тормозит рывками по 100 мс | CPU Throttling в cgroups (`limits.cpu` слишком зажат) |
| On-CPU Flame Graph пустой, а ответы по 3 секунды | Потоки спят в ожидании сети/БД/мьютекса → снимать Off-CPU профиль и трейсы |
| HPA поднял 50 подов, и база данных тут же легла | Connection Storm (`max_connections` превышен) → ставить PgBouncer |
| Redis убит OOM Killer ночью при `maxmemory` < RAM | Copy-on-Write при `fork()` во время `BGSAVE` + Transparent Huge Pages |

> Проверка: `vmstat`, `iostat`, `ss -ltn`, `nstat`, `ulimit -n`,
> `/proc/pressure/*`
> выполнены локально (Linux); не проверено: `redis-cli` команды на живом
> кластере.
