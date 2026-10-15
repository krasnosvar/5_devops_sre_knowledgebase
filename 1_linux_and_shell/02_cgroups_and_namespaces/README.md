# 02. Cgroups и Namespaces

## Зачем
Namespaces и cgroups — это и есть контейнер: изоляция того, что процесс
видит, и лимиты того, сколько он потребляет. Без этого непонятно, почему
под получил OOMKilled при «свободной» памяти на ноде, откуда CPU
throttling при низкой загрузке и как зайти в сеть контейнера с хоста.

## Пререквизиты
- [01_process_model](../01_process_model/) — PID, fork, сигналы, OOM.
- Стенд: 🖥 Tier 2 — Linux VM с sudo и cgroups v2
  ([0_lab_setup/02_local_vms](../../0_lab_setup/02_local_vms/)).

> **Забегание вперёд.** Упражнение 02 использует Docker (подробно — в
> [3_containers](../../3_containers/)), упражнение 04 — kind
> ([0_lab_setup/03_local_k8s](../../0_lab_setup/03_local_k8s/)) и kubectl
> ([4_kubernetes/00_first_steps](../../4_kubernetes/00_first_steps/)).
> Для этой темы достаточно: `docker run -d`/`inspect`/`rm -f`,
> `kind create/delete cluster`, `kubectl apply/get/describe`. Если они ещё
> не освоены — упражнения 02 и 04 можно пропустить и вернуться к ним позже.

## Файлы
- [01_theory/cgroups_namespaces.md](./01_theory/cgroups_namespaces.md) —
  8 типов namespaces, контроллеры cgroups v2 (`cpu.weight`, `cpu.max`,
  `memory.max`, `memory.high`, `pids.max`), v1 как legacy, eBPF.
- [02_examples/cgroup_demo.sh](./02_examples/cgroup_demo.sh) — версия
  cgroups, cgroup текущего процесса и Docker-контейнера, `unshare`.
- [03_exercises/README.md](./03_exercises/README.md) — 4 упражнения
  (PID namespace, namespaces контейнера, OOM в cgroup v2, лимиты в k8s),
  🖥 Tier 2.
- [04_exercises_answers/answers.md](./04_exercises_answers/answers.md) —
  ответы.

## Как проходить
1. Теория → `sudo bash 02_examples/cgroup_demo.sh`.
2. Упражнения 01 и 03 (только Linux), затем 02 и 04, если Docker и kind
   уже установлены.
3. Сверить с [ответами](./04_exercises_answers/answers.md).

## Когда двигаться дальше
- можете объяснить, во что превращаются `requests`/`limits` CPU и памяти
  на уровне файлов cgroup v2;
- можете вручную создать cgroup, ограничить память и найти OOM в
  `memory.events`;
- можете зайти в network namespace контейнера через `nsenter`.

Дальше: [03_file_descriptors_and_io](../03_file_descriptors_and_io/).
