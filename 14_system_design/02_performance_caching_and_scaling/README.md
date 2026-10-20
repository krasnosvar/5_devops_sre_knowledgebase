# 02. Производительность, кэширование и масштабирование

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — законы
> производительности, уровни кэша, HPA/KEDA и лимиты ядра одним экраном.

## Зачем

Когда нагрузка растёт в 10 раз, просто «добавить серверов» перестаёт работать:
система упирается в нелинейный рост очередей (закон Кингмана), последовательные
блокировки (закон Амдала), протухание кэша (cache stampede), исчерпание
соединений к БД (connection storm) или дефолтные лимиты ядра Linux (`ulimit`,
`somaxconn`, `conntrack`). Этот подраздел учит находить реальное узкое место
по метрикам и профилям, правильно выстраивать многоуровневое кэширование и
выбирать стратегию масштабирования (от одного процесса до VM-флота и
Kubernetes).

## Пререквизиты

-
[1_linux_and_shell/08_performance_and_ebpf](../../1_linux_and_shell/08_performance_and_ebpf/)
  — профилирование Linux, `perf`, eBPF.
- [4_kubernetes/10_pod_autoscaling](../../4_kubernetes/10_pod_autoscaling/)
  и
[4_kubernetes/08_cluster_operations](../../4_kubernetes/08_cluster_operations/)
  — HPA/VPA/KEDA и Cluster Autoscaler / Karpenter.
-
[8_observability/01_observability_theory](../../8_observability/01_observability_theory/)
  и [9_sre/07_capacity_planning](../../9_sre/07_capacity_planning/) —
  методологии USE/RED и планирование ёмкости.
- [01_architecture_and_api_styles](../01_architecture_and_api_styles/).

## Файлы

- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: законы Литтла/Амдала,
  паттерны и аномалии кэша, HPA/KEDA, диагностика Linux.
-
[01_theory/01_bottlenecks_and_profiling_methodology.md](./01_theory/01_bottlenecks_and_profiling_methodology.md)
  — триада Throughput/Latency/Concurrency, перцентили, законы Литтла,
  Амдала и Гюнтера (USL), кривая очередей Кингмана, локализация узких мест
  (USE/RED), On-CPU vs Off-CPU Flame Graphs, виды нагрузочных тестов и
  ловушка Coordinated Omission.
-
[01_theory/02_caching_levels_and_patterns.md](./01_theory/02_caching_levels_and_patterns.md)
  — математика Hit/Miss Ratio, уровни кэша L0–L5 (Browser, CDN, Reverse
  Proxy, L1 In-Process, L2 Redis, Buffer Pool), паттерны Cache-Aside,
  Read/Write-Through, Write-Behind, политики LRU/LFU и четыре аномалии
  (Stampede, Avalanche, Penetration, Hot Key).
-
[01_theory/03_scaling_high_load_systems.md](./01_theory/03_scaling_high_load_systems.md)
  — вертикальное vs горизонтальное масштабирование, C10k/C10M (`epoll`,
  `io_uring`, лимиты ядра), масштабирование без Kubernetes (VM-флот, ASG,
  Immutable Infra) и с Kubernetes (HPA, VPA, KEDA, Karpenter,
  Overprovisioning), ловушки stateful-масштабирования (Connection Storm,
  PgBouncer).

Без лабы: тема архитектурная; работающие реализации профилирования и кэшей
на уровне кода доступны в языковых репозиториях:
- [Python: 02_performance_and_scaling](../../../4_python_my_knowledgebase/4_system_design/02_performance_and_scaling/)
- [Go: 02_performance_and_scaling](../../../3_go_my_knowledgebase/3_system_design/02_performance_and_scaling/)

## Как проходить

1. Изучить уроки по порядку: сначала как измерять систему и находить узкое
   место (`01`), затем как разгрузить её многоуровневым кэшем (`02`), и
   наконец как масштабировать вычислительный флот (`03`).
2. Проверить команды экспресс-диагностики (`vmstat`, `iostat`, `ss -ltn`,
   `/proc/pressure/`) на своей рабочей Linux-машине.
3. Ответить на 30 вопросов для собеседования в конце файлов теории.

## Когда двигаться дальше

- Можете по закону Литтла рассчитать размер пула соединений и объяснить,
  почему сервис нельзя грузить на 90% CPU.
- Умеете различать Cache Stampede, Avalanche, Penetration и Hot Key и
  называть точный рецепт для каждого случая.
- Понимаете, почему HPA без Overprovisioning и без PgBouncer не спасает
  при мгновенном 10x всплеске трафика.
- Дальше:
  [03_distributed_components_and_data](../03_distributed_components_and_data/).
