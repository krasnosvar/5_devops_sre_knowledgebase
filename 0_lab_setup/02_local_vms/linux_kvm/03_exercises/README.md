# Упражнения — KVM Lab

## 01 — Поднять 3 VM и проверить SSH доступность

```bash
cd ../02_examples/

# Поднять 3 VM
terraform apply -var="vm_count=3"

# Получить IP адреса
terraform output vm_ips
terraform output ssh_commands

# Проверить SSH ко всем
for ip in $(terraform output -json vm_ips | jq -r '.[]'); do
  echo -n "SSH to $ip: "
  ssh -i ~/.ssh/lab_key -o ConnectTimeout=5 lab@$ip "hostname" 2>/dev/null \
    && echo "OK" || echo "FAILED"
done
```

## 02 — Изменить ресурсы VM через Terraform

**Задача:** Изменить vm_memory_mb с 2048 на 4096 для всех VM, применить без пересоздания.

```bash
# Посмотреть план изменений
terraform plan -var="vm_count=3" -var="vm_memory_mb=4096"

# Применить
terraform apply -var="vm_count=3" -var="vm_memory_mb=4096"

# Убедиться (на VM)
ssh -i ~/.ssh/lab_key lab@<ip> "free -h"
```

## 03 — Snapshot через virsh

```bash
# Создать snapshot одной VM
virsh snapshot-create-as lab-node-1 before-experiment

# Список снапшотов
virsh snapshot-list lab-node-1

# Сделать что-то разрушительное
ssh -i ~/.ssh/lab_key lab@<ip> "sudo rm -rf /etc/hosts"

# Откатиться
virsh snapshot-revert lab-node-1 before-experiment

# Убедиться что откатились
ssh -i ~/.ssh/lab_key lab@<ip> "cat /etc/hosts"
```

## 04 — Terraform destroy и проверка

```bash
# Удалить все VM
terraform destroy

# Убедиться что в libvirt ничего не осталось
virsh list --all | grep lab
virsh vol-list lab

# Снова поднять
terraform apply -var="vm_count=2"
```
