# 02. Слои образов

## Зачем

Размер образа, скорость сборки в CI и время раскатки зависят от того,
как устроены слои: overlay FS, copy-on-write и кэш инструкций Dockerfile.
Тема объясняет, почему порядок инструкций меняет время сборки в разы и как
multi-stage сжимает образ до нескольких мегабайт.

## Пререквизиты

- [01_oci_and_runtimes](../01_oci_and_runtimes/) — что такое образ по OCI.
- [1_linux_and_shell/04_filesystem_and_mounts](../../1_linux_and_shell/04_filesystem_and_mounts/)
  — mount, inode, page cache: основа overlay FS.

## Файлы

- [01_theory/image_layers.md](./01_theory/image_layers.md) — overlay FS,
  copy-on-write, кэш слоёв, multi-stage, distroless.
- [02_examples/](./02_examples/) — `Dockerfile.optimized` (multi-stage
  Python) с `requirements.txt` и `src/main.py`, `.dockerignore`.
- [03_exercises/README.md](./03_exercises/README.md) — 4 упражнения
  (🐳 Tier 1).
- [04_exercises_answers/](./04_exercises_answers/) — ответы
  (`image_layers_answers.md`, `Dockerfile.answer`,
  `Dockerfile.multistage-go`).

## Как проходить

1. Прочитать теорию.
2. Запустить примеры из `02_examples/` и сверить поведение с теорией.
3. Решить упражнения, не подглядывая в ответы.
4. Сверить с `04_exercises_answers/`.

## Когда двигаться дальше

- Можете объяснить, какой слой инвалидирует кэш и почему.
- Можете без подсказки написать multi-stage Dockerfile для Go в `scratch`.
- Можете найти «wasted space» в образе через `dive`.

Дальше: [03_networking](../03_networking/).
