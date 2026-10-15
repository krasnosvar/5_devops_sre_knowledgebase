# 05. Безопасность контейнеров

## Зачем

Контейнер делит ядро с хостом, поэтому root в контейнере с лишними
capabilities — прямой путь к побегу на ноду. Тема учит запускать контейнеры
с минимальными правами: capabilities, seccomp, read-only rootfs, non-root,
сканирование образов.

## Пререквизиты

- [1_linux_and_shell/09_linux_security](../../1_linux_and_shell/09_linux_security/) —
  capabilities, seccomp, AppArmor/SELinux.
- [1_linux_and_shell/10_users_and_permissions](../../1_linux_and_shell/10_users_and_permissions/)
  — UID/GID, права.
- [02_image_layers](../02_image_layers/) — сборка образов.

> **Забегание вперёд.** В теории упоминаются `securityContext` и Pod
> Security Standards Kubernetes, которые подробно разбираются в
> [4_kubernetes/06_security](../../4_kubernetes/06_security/) и
> [10_devsecops/05_pod_security](../../10_devsecops/05_pod_security/). Для
> этой темы достаточно понимать, что это те же capabilities/non-root,
> только заданные в манифесте пода. Можно пропустить и вернуться позже.

## Файлы

- [01_theory/container_security.md](./01_theory/container_security.md) —
  capabilities, seccomp/AppArmor, user namespaces, rootless, SecurityContext.
- [02_examples/](./02_examples/) — `Dockerfile.secure`, `run-secure.sh`
  (nginx с `--cap-drop ALL`, read-only rootfs, лимитами).
- [03_exercises/README.md](./03_exercises/README.md) — 4 упражнения
  (🐳 Tier 1; для 03-04 нужны `trivy` и `hadolint`).
- [04_exercises_answers/](./04_exercises_answers/) — ответы
  (`security_answers.md`, `Dockerfile.fixed`).

## Как проходить

1. Прочитать теорию.
2. Запустить примеры из `02_examples/` и сверить поведение с теорией.
3. Решить упражнения, не подглядывая в ответы.
4. Сверить с `04_exercises_answers/`.

## Когда двигаться дальше

- Можете без подсказки назвать минимальный набор capabilities для
  официального nginx и объяснить каждый.
- Можете запустить сервис с `--read-only` и нужными tmpfs.
- Можете перечислить проблемы небезопасного Dockerfile и исправить их.

Дальше: [06_compose_patterns](../06_compose_patterns/).
