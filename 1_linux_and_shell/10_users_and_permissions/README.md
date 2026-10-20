# 10. Пользователи, группы и ACL

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — команды и шаблоны одним экраном.

## Зачем
Права «не работают», пользователь потерял доступ к docker после
`usermod -G`, сервисный аккаунт может залогиниться, файлы в общей
директории создаются с чужой группой — всё это про устройство учётных
записей, групп, NSS и ACL. Тема про то, как ОС вообще знает, кто вы.

## Пререквизиты
- [01_process_model](../01_process_model/) — UID/GID процесса.
- [04_filesystem_and_mounts](../04_filesystem_and_mounts/) — inodes
  (права хранятся в inode).
- Стенд: 🐳 Tier 1 — контейнер Ubuntu с root внутри.

> **Забегание вперёд.** Упражнения запускаются в Docker-контейнере
> (Docker подробно — в [3_containers](../../3_containers/)). Достаточно
> `docker run --rm -it ubuntu:22.04 bash`; подойдёт и одноразовая VM.

## Файлы
- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: useradd/usermod, права, ACL.
- [01_theory/users_and_permissions.md](./01_theory/users_and_permissions.md)
  — `/etc/passwd`/`shadow`/`group`, useradd/usermod, primary vs
  supplementary группы, NSS, ACL (default ACL, mask, POSIX vs NFSv4).
- [02_examples/users_and_acl_demo.sh](./02_examples/users_and_acl_demo.sh)
  — анатомия учётной записи, группы, ACL на практике.
- [03_exercises/README.md](./03_exercises/README.md) — 5 упражнений
  (системные vs логин-аккаунты, ловушка `usermod -G`, newgrp, default ACL,
  mask), 🐳 Tier 1.
- [04_exercises_answers/answers.md](./04_exercises_answers/answers.md) —
  ответы.

## Как проходить
1. Теория → `sudo bash 02_examples/users_and_acl_demo.sh` (в контейнере
   или VM).
2. Упражнения 01-05 по порядку в одном контейнере.
3. Сверить с [ответами](./04_exercises_answers/answers.md).

## Когда двигаться дальше
- можете объяснить, чем `usermod -G` отличается от `usermod -aG`;
- можете объяснить, откуда `id` берёт группы при LDAP (NSS);
- можете объяснить, что такое ACL mask и почему `chmod g-w` её меняет.

Дальше: [11_troubleshooting](../11_troubleshooting/).
