# 04. Хранение данных контейнеров

## Зачем

Данные, записанные в слой контейнера, исчезают вместе с ним. Тема
разбирает volumes, bind mounts и tmpfs: где данные реально лежат, как их
бэкапить и почему это напрямую переходит в PV/PVC Kubernetes.

## Пререквизиты

- [02_image_layers](../02_image_layers/) — writable-слой и copy-on-write.
- [1_linux_and_shell/04_filesystem_and_mounts](../../1_linux_and_shell/04_filesystem_and_mounts/)
  — mount, bind mount, tmpfs.

> **Забегание вперёд.** Разделы 3-5 теории описывают хранилище Kubernetes,
> которое подробно разбирается в
> [4_kubernetes/04_storage](../../4_kubernetes/04_storage/). Для этой темы
> достаточно знать, что под — это группа контейнеров, а PVC — заявка пода
> на диск. Если Kubernetes ещё не освоен — эти разделы можно пропустить и
> вернуться к ним позже.

## Файлы

- [01_theory/container_storage.md](./01_theory/container_storage.md) —
  почему writable-слой не для данных, volumes и bind mounts; CSI, PV/PVC/
  StorageClass, access modes в Kubernetes.
- [02_examples/](./02_examples/) — `volumes_demo.yaml` (named volume, bind
  mount `static/`, tmpfs, read-only rootfs) и `static/index.html`.
- Без отдельных упражнений: backup/restore volume отрабатывается в
  упражнении 02 темы [06_compose_patterns](../06_compose_patterns/).

## Как проходить

1. Прочитать теорию.
2. Поднять `docker compose -f volumes_demo.yaml up -d`, найти данные volume
   на хосте (`docker volume inspect`), проверить, что bind mount read-only,
   а tmpfs пустеет после рестарта.
3. `docker compose -f volumes_demo.yaml down -v`.

## Когда двигаться дальше

- Можете объяснить, где на хосте лежат данные named volume.
- Можете выбрать между volume, bind mount и tmpfs для конкретной задачи.
- Можете объяснить, что сломается при `--read-only` без tmpfs.

Дальше: [05_security](../05_security/).
