# Упражнения — Пользователи, группы, ACL

Стенд: 🐳 Tier 1 — контейнер Ubuntu/Debian (нужен реальный root внутри, kind/k8s не подходит)

```bash
docker run --rm -it --name userlab ubuntu:22.04 bash
apt-get update -qq && apt-get install -y -qq acl sudo
```

## 01 — Создать логин-пользователя и системный аккаунт, сравнить UID

```bash
useradd -m -s /bin/bash -c "Alice Smith" alice
useradd -r -s /usr/sbin/nologin svc_backup

grep -E "^(alice|svc_backup):" /etc/passwd
# TODO: почему у alice UID >= 1000, а у svc_backup — меньше 1000?
# Проверь /etc/login.defs (UID_MIN/UID_MAX, SYS_UID_MIN/SYS_UID_MAX)
```

## 02 — Поймать ловушку usermod -G

**Задача:** Добавить alice в группу `docker`, затем случайно "потерять" это членство неправильной командой.

```bash
groupadd docker
groupadd developers
usermod -aG docker alice
id alice   # должна быть в docker

# TODO: выполни usermod -G developers alice (БЕЗ -a) и снова проверь id alice
# Объясни, что произошло с группой docker
```

## 03 — newgrp: временно переключить активную группу без релогина

**Задача:** Понять, что `newgrp` не "обновляет" список групп пользователя, а временно
переключает primary group ТЕКУЩЕГО процесса — используется, когда группа уже назначена,
но нужно, чтобы именно ОНА была активной для следующей команды (например, для владения
новыми файлами).

```bash
usermod -aG developers alice
su - alice -c "id -gn"                       # активная (primary) группа — alice
su - alice -c "newgrp developers <<< 'id -gn; touch /tmp/f_via_newgrp; ls -l /tmp/f_via_newgrp'"
# TODO: у какой ГРУППЫ окажется файл /tmp/f_via_newgrp — alice или developers? Почему?
```

## 04 — Default ACL: наследование прав новыми файлами

```bash
mkdir -p /opt/shared
setfacl -d -m u:alice:rx /opt/shared/
touch /opt/shared/report.txt
getfacl --absolute-names /opt/shared/report.txt
# TODO: почему у report.txt уже есть ACL-запись для alice, хотя ты
# ни разу не вызывал setfacl на сам этот файл?
```

## 05 — mask: почему ACL-права "не работают"

```bash
touch /opt/config.yaml
setfacl -m u:alice:rwx /opt/config.yaml
getfacl --absolute-names /opt/config.yaml   # у alice должно быть rwx

setfacl -m mask::r-- /opt/config.yaml
getfacl --absolute-names /opt/config.yaml
# TODO: что показывает getfacl теперь рядом с записью alice?
# Как вернуть alice реальные rwx, не трогая её собственную ACL-запись?
```
