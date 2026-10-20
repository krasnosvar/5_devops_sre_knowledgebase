# 07. Bash для DevOps

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — команды и шаблоны одним экраном.

## Зачем
Bash остаётся клеем инфраструктуры: entrypoint'ы контейнеров, шаги
CI, setup-скрипты, обёртки над kubectl/terraform. Тема — не про синтаксис,
а про паттерны, без которых скрипт опасен в проде: strict mode,
идемпотентность, retry с backoff, trap/cleanup, lockfile, jq.

## Пререквизиты
- [01_process_model](../01_process_model/) — сигналы, subshell = fork.
- [03_file_descriptors_and_io](../03_file_descriptors_and_io/) —
  перенаправления и pipes.
- Стенд: 🐳 Tier 1 — любой Linux с bash, `jq`, `curl`.

> **Забегание вперёд.** Упражнение 03 работает с выводом
> `kubectl get pods -o json` (kubectl — в
> [4_kubernetes/00_first_steps](../../4_kubernetes/00_first_steps/)), но
> кластер не нужен: образец данных лежит в `03_exercises/test-pods.json`.
> Ответ к упражнению 01 удобно проверять в одноразовом Docker-контейнере
> (Docker — в [3_containers](../../3_containers/)); подойдёт и любая VM.

## Файлы
- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: каркас скрипта, strict mode, ловушки.
- [01_theory/bash_devops_patterns.md](./01_theory/bash_devops_patterns.md)
  — subshells, перенаправления, strict mode, env vs локальные переменные,
  trap.
- [02_examples/devops_toolkit.sh](./02_examples/devops_toolkit.sh) —
  готовые функции: retry, ожидание URL, логирование, проверка
  зависимостей, разбор JSON.
- [03_exercises/README.md](./03_exercises/README.md) — 5 упражнений
  (идемпотентность, retry, jq, мониторинг диска, параллельный деплой),
  🐳 Tier 1.
- [04_exercises_answers/README.md](./04_exercises_answers/README.md) —
  разбор ответов и скрипты-решения.

## Как проходить
1. Теория → прочитать `devops_toolkit.sh`.
2. Решить упражнения 01-05 самостоятельно, прогоняя каждый скрипт через
   `bash -n` и реальный запуск (автопроверки нет).
3. Сверить с [ответами](./04_exercises_answers/README.md).

## Когда двигаться дальше
- можете объяснить, что делает каждая часть `set -euo pipefail` и где
  она не спасает;
- можете без подсказки написать retry с экспоненциальным backoff и
  lockfile на `flock`;
- можете вытащить нужные поля из JSON через jq с учётом отсутствующих полей.

Дальше: [08_performance_and_ebpf](../08_performance_and_ebpf/).
