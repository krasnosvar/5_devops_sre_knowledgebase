#!/usr/bin/env bash
# Демонстрация монтирования, bind mounts, overlayfs

echo "=== Смонтированные ФС ==="
findmnt --output TARGET,SOURCE,FSTYPE,SIZE,USE% --real 2>/dev/null \
    || mount | grep -v "proc\|sys\|dev\|run" | head -10

echo -e "\n=== tmpfs — RAM диск ==="
mkdir -p /tmp/ramdisk_demo
mount -t tmpfs tmpfs /tmp/ramdisk_demo -o size=10m 2>/dev/null \
    || sudo mount -t tmpfs tmpfs /tmp/ramdisk_demo -o size=10m 2>/dev/null \
    || { echo "(требуется root для mount)"; exit 0; }
df -h /tmp/ramdisk_demo
echo "test" > /tmp/ramdisk_demo/file.txt
echo "Файл в tmpfs: $(cat /tmp/ramdisk_demo/file.txt)"
umount /tmp/ramdisk_demo
rmdir /tmp/ramdisk_demo
echo "После unmount файл исчез (tmpfs = RAM)"

echo -e "\n=== Bind mount ==="
mkdir -p /tmp/source /tmp/target
echo "original" > /tmp/source/data.txt
mount --bind /tmp/source /tmp/target 2>/dev/null \
    || sudo mount --bind /tmp/source /tmp/target 2>/dev/null \
    || { echo "(требуется root)"; rm -rf /tmp/source /tmp/target; exit 0; }
echo "Через bind mount: $(cat /tmp/target/data.txt)"
echo "modified" > /tmp/target/data.txt
echo "Оригинал изменился: $(cat /tmp/source/data.txt)"
umount /tmp/target
rm -rf /tmp/source /tmp/target

echo -e "\n=== inode информация ==="
echo "inode /etc/hosts: $(stat -c '%i' /etc/hosts)"
echo "inode /etc/passwd: $(stat -c '%i' /etc/passwd)"
# Жёсткая ссылка — одинаковый inode
cp /etc/hosts /tmp/hosts_copy
ln /tmp/hosts_copy /tmp/hosts_hardlink
echo "inode copy: $(stat -c '%i' /tmp/hosts_copy)"
echo "inode hardlink: $(stat -c '%i' /tmp/hosts_hardlink)"
echo "(одинаковые = один inode, два имени)"
rm /tmp/hosts_copy /tmp/hosts_hardlink
