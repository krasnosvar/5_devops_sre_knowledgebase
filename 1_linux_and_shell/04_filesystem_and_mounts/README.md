# 04. Файловая система и монтирование

## Зачем
«No space left on device» при свободных гигабайтах (кончились inodes),
медленный диск, который на деле — page cache, и слои Docker-образа — всё
это VFS, inodes, page cache и OverlayFS. Тема нужна, чтобы разбирать
проблемы с дисками на нодах и понимать, как устроена файловая система
контейнера.

## Пререквизиты
- [03_file_descriptors_and_io](../03_file_descriptors_and_io/) — fd и
  системные вызовы ввода-вывода.
- [02_cgroups_and_namespaces](../02_cgroups_and_namespaces/) — mount
  namespace.
- Стенд: Linux VM с sudo (🖥 Tier 2) — для mount/overlay нужен root.

## Файлы
- [01_theory/filesystem_mounts.md](./01_theory/filesystem_mounts.md) —
  VFS, inodes, page cache, swap, ext4 vs XFS, LVM, bind mount, tmpfs,
  OverlayFS.
- [02_examples/mounts_demo.sh](./02_examples/mounts_demo.sh) — `findmnt`,
  tmpfs, bind mount, inode и жёсткие ссылки.
- Без отдельных упражнений: закрепляйте, запуская и модифицируя пример.

## Как проходить
1. Прочитать теорию.
2. Запустить `sudo bash 02_examples/mounts_demo.sh`, разобрать каждый блок.
3. Ответить на Interview Q&A без подсказки.

## Когда двигаться дальше
- можете объяснить разницу между `df -h` и `df -i` и когда кончаются inodes;
- можете объяснить, как OverlayFS собирает слои образа и что такое
  copy-on-write;
- можете объяснить, почему `free` показывает мало свободной памяти и это
  нормально.

Дальше: [05_systemd](../05_systemd/).
