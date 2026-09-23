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

## 05 — Кластерный стенд: master + workers

🐳 Tier 1 (VM внутри Tier 2, но задача — про Terraform, а не про k8s)

```bash
cd ../02_examples/cluster/
terraform init
terraform apply -var="master_count=1" -var="worker_count=2"
terraform output ssh_commands
```

**Задача:** увеличить кластер до 1 master + 3 workers без пересоздания
существующих VM (`terraform plan` не должен показывать replace для уже
поднятых узлов).

## 06 — Multi-OS: одна и та же задача на разных дистрибутивах

```bash
cd ../02_examples/multi_os/
terraform init
terraform apply
terraform output ssh_commands
```

**Задача:** зайти на все три VM (ubuntu-24-04, debian-12, rocky-9) и
одной и той же логической командой (установить `nginx` и убедиться что
процесс слушает :80) показать разницу пакетного менеджера
(apt vs dnf) и systemd unit (`systemctl status nginx`).

## 07 — Troubleshooting: три сломанных VM

☁️ По духу задачи взяты из реальных секций troubleshooting на технических
собеседованиях DevOps (например Yandex) — вас сажают за SSH в сломанный
стенд и просят вернуть 200/нормальную работу, не объясняя что именно не так.

```bash
cd ../02_examples/broken/
terraform init
terraform apply
terraform output ssh_commands
```

Три VM, три независимых кейса. Диагностируй и почини **до того**, как
подсмотришь в `../04_exercises_answers/`:

- **broken-logs** — сервис `myapp` должен каждые 5 секунд дописывать строку
  в `/var/log/myapp.log`. Он этого не делает. Почему и как починить, не
  трогая сам скрипт `/usr/local/bin/myapp.sh`?
- **broken-cpu** — на VM разряжен CPU в 100% одним процессом. Найди процесс,
  пойми что он делает не так, и приведи нагрузку в нормальное состояние.
- **broken-504** — `curl http://localhost/ping` отдаёт `504 Gateway Time-out`
  вместо `200`. Найди, где по цепочке nginx → backend рвётся ответ, и
  верни `200`.

```bash
terraform destroy
```
