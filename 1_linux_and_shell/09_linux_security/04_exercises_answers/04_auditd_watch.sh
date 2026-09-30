#!/usr/bin/env bash
# Ответ: упражнение 04 — auditd слежка за критичными файлами
# Демонстрирует: временные и постоянные правила аудита + расследование через ausearch

echo "=== Временные правила (пропадут после reboot) ==="
sudo auditctl -w /etc/sudoers -p wa -k sudoers_watch
sudo auditctl -w /etc/shadow -p wa -k shadow_watch
sudo auditctl -l | grep -E "sudoers_watch|shadow_watch"

echo -e "\n=== Провоцируем событие ==="
sudo visudo -c   # проверка синтаксиса sudoers — тоже задевает файл через open()

echo -e "\n=== Расследование: кто и когда трогал файл ==="
sudo ausearch -k sudoers_watch -ts recent

echo -e "\n=== Сводка по всем изменениям прав/владельца в системе ==="
sudo aureport -f -i --summary 2>/dev/null | head -20

echo -e "\n=== Делаем правило постоянным ==="
RULES_FILE=/etc/audit/rules.d/hardening.rules
echo "-w /etc/sudoers -p wa -k sudoers_watch" | sudo tee -a "$RULES_FILE" > /dev/null
echo "-w /etc/shadow -p wa -k shadow_watch"   | sudo tee -a "$RULES_FILE" > /dev/null
sudo augenrules --load
echo "Правила из $RULES_FILE теперь переживут перезагрузку"
