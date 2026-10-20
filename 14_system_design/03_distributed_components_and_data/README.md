# 03. Распределённые компоненты: данные, очереди и отказоустойчивость

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — кворумы, шардинг,
> Kafka vs RabbitMQ, Rate Limiting, Circuit Breaker и Graceful Shutdown одним
> экраном.

## Зачем

Любая крупная система опирается на три распределённых столпа: масштабируемое
хранение данных (репликация и шардирование), асинхронную передачу событий
через брокеры сообщений и защитные механизмы на пути сетевого трафика. Ошибка
в любом из них приводит либо к потере и рассинхронизации данных (Split-Brain,
Dual Write), либо к каскадному падению всей платформы из-за шторма ретраев и
забитых пулов соединений.

## Пререквизиты

- [2_networking/03_load_balancing](../../2_networking/03_load_balancing/) —
  сетевая механика L4 и L7 балансировщиков (NAT, DSR, HAProxy, nginx, Envoy).
- [4_kubernetes/02_workloads](../../4_kubernetes/02_workloads/) —
  жизненный цикл пода, `liveness`/`readiness`/`startup` пробы, `StatefulSet`.
- [02_performance_caching_and_scaling](../02_performance_caching_and_scaling/).

## Файлы

- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: репликация, шардинг, брокеры,
  алгоритмы балансировки и паттерны отказоустойчивости.
-
[01_theory/01_data_replication_sharding_and_cap.md](./01_theory/01_data_replication_sharding_and_cap.md)
  — Single-Leader, Multi-Leader и Leaderless (Quorum $W + R > N$) репликация,
  аномалии репликационного лага (Read-Your-Writes, Monotonic Reads),
  партиционирование и шардирование, Consistent Hashing с виртуальными узлами,
  теоремы CAP и PACELC, распределённые транзакции (2PC vs Saga), B-Tree vs
  LSM-Tree.
-
[01_theory/02_messaging_and_async_patterns.md](./01_theory/02_messaging_and_async_patterns.md)
  — сравнение архитектур Kafka, RabbitMQ и NATS, устройство партиций и
  Consumer Groups в Kafka, гарантии доставки (`At-Most-Once`, `At-Least-Once`,
  `Exactly-Once`), проблема двойной записи и паттерны Transactional Outbox /
  Inbox, идемпотентные консьюмеры, Retries, DLQ и Backpressure.
-
[01_theory/03_load_balancing_and_resilience_patterns.md](./01_theory/03_load_balancing_and_resilience_patterns.md)
  — анатомия каскадных отказов, алгоритмы балансировки (включая Power of Two
  Random Choices), активные и пассивные проверки здоровья (Outlier Detection),
  Rate Limiting (Token Bucket, Leaky Bucket, Sliding Window), сквозные
  дедлайны, Retries с Exponential Backoff & Full Jitter, Circuit Breaker,
  Bulkhead, Load Shedding и безупречный Graceful Shutdown в Kubernetes.

Без лабы: тема разбирает фундаментальную архитектуру распределённых систем;
практические примеры кода и упражнения на языках программирования находятся в:
- [Python: 03_distributed_components](../../../4_python_my_knowledgebase/4_system_design/03_distributed_components/)
- [Go: 03_distributed_components](../../../3_go_my_knowledgebase/3_system_design/03_distributed_components/)

## Как проходить

1. Прочитать три урока последовательно: хранение данных (`01`) → асинхронные
   потоки событий (`02`) → защита сетевого контура от каскадных сбоев (`03`).
2. Проверить в своих рабочих сервисах: нет ли проверки БД в `livenessProbe`,
   есть ли `preStop` хук перед `SIGTERM` и используется ли Jitter в ретраях.
3. Ответить на 30 вопросов для собеседования в конце файлов теории.

## Когда двигаться дальше

- Можете объяснить, как решить проблему Read-Your-Writes на асинхронных
  репликах и зачем в Consistent Hashing нужны виртуальные узлы.
- Понимаете, почему `At-Least-Once + Idempotent Consumer` заменяет
  распределённые транзакции, и как работает Transactional Outbox с
  `FOR UPDATE SKIP LOCKED`.
- Умеете объяснить гонку между `EndpointSlice` и `SIGTERM` при удалении пода
  в Kubernetes.
- Дальше: [04_single_vs_multi_cluster](../04_single_vs_multi_cluster/).
