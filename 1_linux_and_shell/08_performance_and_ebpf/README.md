# 08. Производительность и eBPF

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — команды и шаблоны одним экраном.

## Зачем
Когда метрик недостаточно, а перезапускать приложение с отладкой
нельзя, нужна наблюдаемость на уровне ядра: eBPF-инструменты (bpftrace,
bcc), kprobes/uprobes, XDP. На них же построены современные CNI (Cilium),
профилировщики и security-агенты.

## Пререквизиты
- [01_process_model](../01_process_model/) и
  [03_file_descriptors_and_io](../03_file_descriptors_and_io/) — процессы,
  системные вызовы, I/O.
- [06_networking_basics](../06_networking_basics/) — сетевой стек (для
  XDP).
- Стенд: Linux VM с современным ядром и sudo (🖥 Tier 2); в контейнере
  eBPF требует привилегий.

## Файлы
- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: bpftrace, BCC, perf, strace.
- [01_theory/ebpf_and_observability.md](./01_theory/ebpf_and_observability.md)
  — от модулей ядра к eBPF, верификатор и JIT, XDP, kprobes/uprobes и
  bpftrace, io_uring.
- Без примеров и упражнений: команды bpftrace для экспериментов — в
  теории; практика диагностики — в
  [11_troubleshooting](../11_troubleshooting/).

## Как проходить
1. Прочитать теорию.
2. Если есть VM: установить `bpftrace` и повторить однострочники из теории.
3. Ответить на Interview Q&A без подсказки.

## Когда двигаться дальше
- можете объяснить, почему eBPF-программа не может уронить ядро
  (верификатор);
- можете объяснить, чем kprobe отличается от uprobe и прочитать
  однострочник bpftrace;
- можете объяснить, где работает XDP и почему он быстрее iptables.

Дальше: [09_linux_security](../09_linux_security/).
