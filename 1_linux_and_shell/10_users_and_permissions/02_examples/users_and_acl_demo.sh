#!/usr/bin/env bash
# Демонстрация: учётные записи, группы, ACL (нужен root или sudo)

echo "=== Анатомия /etc/passwd для текущего пользователя ==="
grep "^$(whoami):" /etc/passwd

echo -e "\n=== Системные vs логин-пользователи (по UID) ==="
echo "Системные (UID < 1000):"
awk -F: '$3 < 1000 {print "  "$1" (UID "$3")"}' /etc/passwd | head -5
echo "Логин-пользователи (UID >= 1000):"
awk -F: '$3 >= 1000 && $3 < 60000 {print "  "$1" (UID "$3")"}' /etc/passwd

echo -e "\n=== NSS: откуда резолвится пользователь ==="
cat /etc/nsswitch.conf 2>/dev/null | grep -E "^passwd|^group" || echo "(nsswitch.conf недоступен в этом окружении)"
getent passwd "$(whoami)"

echo -e "\n=== Группы текущего пользователя (primary + supplementary) ==="
id

echo -e "\n=== ACL: создать точечный доступ и посмотреть mask ==="
DEMO_FILE=$(mktemp)
setfacl -m u:nobody:rwx "$DEMO_FILE" 2>/dev/null && {
    getfacl --absolute-names "$DEMO_FILE"
    echo "--- ls -l (обрати внимание на '+' в правах) ---"
    ls -l "$DEMO_FILE"
} || echo "(setfacl недоступен — установи пакет acl)"
rm -f "$DEMO_FILE"
