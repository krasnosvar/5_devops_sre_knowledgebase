# 07. Dockerfile: лучшие практики

## Зачем

Неправильная форма `CMD`, shell-обёртка в PID 1 или секрет в `ARG`
приводят к контейнерам, которые не завершаются по SIGTERM, теряют запросы
при раскатке или светят пароли в `docker history`. Тема собирает практики
написания Dockerfile, которые важны в продакшене.

## Пререквизиты

- [02_image_layers](../02_image_layers/) — слои и кэш.
- [1_linux_and_shell/01_process_model](../../1_linux_and_shell/01_process_model/) — PID 1,
  сигналы, зомби-процессы.

## Файлы

- [01_theory/dockerfile_best_practices.md](./01_theory/dockerfile_best_practices.md)
  — shell vs exec form, PID 1 и сигналы, ENTRYPOINT + CMD, BuildKit
  secrets и cache mounts, `.dockerignore`.
- Без примеров и упражнений: практика — в
  [02_image_layers](../02_image_layers/) и [05_security](../05_security/)
  (упражнение 04 — hardening Dockerfile).

## Как проходить

1. Прочитать теорию.
2. Проверить на своём Dockerfile: exec form у `CMD`/`ENTRYPOINT`, корректная
   обработка SIGTERM (`docker stop` завершается быстро, а не через 10 с),
   отсутствие секретов в `docker history`.

## Когда двигаться дальше

- Можете объяснить, почему shell form `CMD` ломает graceful shutdown.
- Можете передать секрет в сборку через `RUN --mount=type=secret`.
- Можете объяснить связку ENTRYPOINT + CMD.

Дальше: раздел [4_kubernetes](../../4_kubernetes/).
