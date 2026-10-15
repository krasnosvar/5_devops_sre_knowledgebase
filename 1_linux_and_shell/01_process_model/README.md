# 01. Процессная модель Linux

## Зачем
Контейнер — это просто процесс, поэтому всё, что происходит с ним в
проде (zombie в контейнере без init, потерянный SIGTERM при остановке
пода, OOM Killer, «память кончилась, но RSS маленький»), объясняется
процессной моделью: fork/exec, сигналы, wait, /proc, VSZ vs RSS.

## Пререквизиты
- [00_architecture_and_boot](../00_architecture_and_boot/) — что такое
  системный вызов и user space.
- Стенд: любой Linux с bash, `ps`, `pstree`, `python3`
  ([0_lab_setup](../../0_lab_setup/), 🐳 Tier 1 тоже подходит).
- Базовый Python для чтения коротких программ на `os.fork()`/`signal`.

## Файлы
- [01_theory/process_model.md](./01_theory/process_model.md) — процесс и
  память (VSZ/RSS), IPC, fork/exec, zombie/orphan, сигналы и OOM Killer,
  nice/renice.
- [02_examples/signals_demo.sh](./02_examples/signals_demo.sh) — graceful
  shutdown по SIGTERM, чтение `/proc/<pid>/status`, fork+exec в shell.
- [03_exercises/README.md](./03_exercises/README.md) — 4 упражнения
  (fork/exec, zombie, SIGTERM vs SIGKILL, /proc), 🐳 Tier 1.
- [04_exercises_answers/](./04_exercises_answers/) — ответы
  ([answers.md](./04_exercises_answers/answers.md)) и Python-программы
  к упражнениям 01-03.

## Как проходить
1. Теория → запустить `bash 02_examples/signals_demo.sh`.
2. Сделать упражнения 01-04, наблюдая процессы через `ps`/`pstree`/`/proc`.
3. Сверить с [ответами](./04_exercises_answers/answers.md).

## Когда двигаться дальше
- можете без подсказки объяснить, откуда берётся zombie и почему
  `kill -9` его не убирает;
- можете объяснить, почему приложение в контейнере не получает SIGTERM,
  если запущено через `sh -c`;
- можете по `/proc/<pid>/status` сказать, сколько процесс реально занимает
  в RAM.

Дальше: [02_cgroups_and_namespaces](../02_cgroups_and_namespaces/).
