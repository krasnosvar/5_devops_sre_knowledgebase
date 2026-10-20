# 01. OCI и container runtimes

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — быстрый
> справочник команд, флагов и типовых конфигов.

## Зачем

«Контейнер» — это не Docker, а набор стандартов (OCI) и цепочка
программ: Docker/containerd → runc → namespaces + cgroups ядра. Это нужно,
чтобы понимать, почему Kubernetes работает без Docker, что делает `crictl`
на ноде и чем runc отличается от gVisor и Kata.

## Пререквизиты

- [1_linux_and_shell/02_cgroups_and_namespaces](../../1_linux_and_shell/02_cgroups_and_namespaces/)
  — механизмы ядра, из которых состоит контейнер.
- [1_linux_and_shell/01_process_model](../../1_linux_and_shell/01_process_model/) — `clone`,
  `execve`, PID 1.

## Файлы

- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: цепочка runtime, crictl/ctr,
  RuntimeClass.
- [01_theory/oci_runtimes.md](./01_theory/oci_runtimes.md) — OCI image/
  runtime/distribution spec, containerd, runc, crun, gVisor, Kata, Podman.
- [02_examples/](./02_examples/) — `runtime_compare.sh` (Docker vs crictl,
  runtime, overlay mounts), `Dockerfile.distroless` + `main.go`/`go.mod`
  (сборка distroless-образа).
- Без упражнений: тема концептуальная, практика сборки и запуска — в
  [02_image_layers](../02_image_layers/) и [05_security](../05_security/).

## Как проходить

1. Прочитать теорию.
2. Запустить примеры из `02_examples/`, поменять параметры и наблюдать
   результат (`docker inspect`, `docker logs`).

## Когда двигаться дальше

- Можете нарисовать цепочку dockerd → containerd → shim → runc → процесс.
- Можете объяснить, почему Kubernetes отказался от dockershim и что от этого
  не сломалось.
- Можете объяснить разницу runc, gVisor и Kata по уровню изоляции.

Дальше: [02_image_layers](../02_image_layers/).
