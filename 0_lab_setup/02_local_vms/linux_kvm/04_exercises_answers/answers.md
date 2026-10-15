# Ответы — упражнения 01–06 (KVM Lab)

Условия — [03_exercises/README.md](../03_exercises/README.md). Ответ на
упражнение 07 (сломанные VM) — в [broken-vm-answers.md](./broken-vm-answers.md).
Во всех ответах подразумевается `export LIBVIRT_DEFAULT_URI=qemu:///system`.

## Упражнение 1 — Поднять 3 VM и проверить SSH доступность

```bash
cd ../02_examples/
terraform init
terraform plan -var="vm_count=3"
terraform apply -var="vm_count=3"
terraform output vm_ips
for ip in $(terraform output -json vm_ips | jq -r '.[]'); do
  echo -n "SSH to $ip: "
  ssh -i ~/.ssh/lab_key -o ConnectTimeout=5 lab@"$ip" hostname
done
```

Ожидаемый вывод (примерно так):

```text
Plan: 12 to add, 0 to change, 0 to destroy.
...
Apply complete! Resources: 12 added, 0 changed, 0 destroyed.
[
  "192.168.200.11",
  "192.168.200.12",
  "192.168.200.13",
]
SSH to 192.168.200.11: lab-node-1
SSH to 192.168.200.12: lab-node-2
SSH to 192.168.200.13: lab-node-3
```

Почему так: 12 ресурсов = pool + base image + сеть + по 3 штуки
(диск, cloud-init ISO, domain). `wait_for_lease = true` заставляет
Terraform дождаться DHCP-адреса, поэтому `vm_ips` заполнен сразу после
`apply`. Первый SSH может спросить про fingerprint — ответьте `yes`.

## Упражнение 2 — Изменить ресурсы VM через Terraform

```bash
terraform plan -var="vm_count=3" -var="vm_memory_mb=4096"
```

Ожидаемый вывод (примерно так):

```text
  # libvirt_domain.lab_node[0] must be replaced
-/+ resource "libvirt_domain" "lab_node" {
      ~ memory = 2048 -> 4096 # forces replacement
...
Plan: 3 to add, 0 to change, 3 to destroy.
```

```bash
terraform apply -var="vm_count=3" -var="vm_memory_mb=4096"
ssh -i ~/.ssh/lab_key lab@<ip> "free -h | head -n 2"
```

```text
               total        used        free      shared  buff/cache   available
Mem:           3.8Gi       250Mi       3.3Gi       1.0Mi       300Mi       3.5Gi
```

Почему так: в провайдере `dmacvicar/libvirt` 0.8.x атрибуты `memory` и
`vcpu` у `libvirt_domain` помечены как ForceNew — изменить их «на месте»
нельзя, domain пересоздаётся. Диски (`libvirt_volume.vm_disk`) не меняются,
поэтому данные на них переживают пересоздание VM, но cloud-init и
in-memory состояние — нет. Главный навык: читать `plan` до `apply`.

## Упражнение 3 — Snapshot через virsh

```bash
virsh snapshot-create-as lab-node-1 before-experiment
virsh snapshot-list lab-node-1
ssh -i ~/.ssh/lab_key lab@<ip> "sudo rm -f /etc/hosts; ls /etc/hosts"
virsh snapshot-revert lab-node-1 before-experiment
ssh -i ~/.ssh/lab_key lab@<ip> "head -n 2 /etc/hosts"
virsh snapshot-delete lab-node-1 before-experiment
```

Ожидаемый вывод (примерно так):

```text
Domain snapshot before-experiment created
 Name                Creation Time               State
---------------------------------------------------------
 before-experiment   2026-10-14 10:00:00 +0000   running
ls: cannot access '/etc/hosts': No such file or directory
127.0.0.1 localhost
127.0.1.1 lab-node-1.lab.local lab-node-1
Domain snapshot before-experiment deleted
```

Почему так: snapshot работающей VM — внутренний (internal) снимок qcow2
вместе с памятью; `snapshot-revert` возвращает и диск, и состояние RAM.
Если libvirt откажется снимать internal snapshot из-за cloud-init ISO,
отключите VM от него или используйте `--disk-only` (external snapshot) —
у них свой порядок отката, см. документацию libvirt. Удалите
снимок до `terraform destroy`: libvirt не даст удалить domain со снимками.

## Упражнение 4 — Terraform destroy и проверка

```bash
terraform destroy -var="vm_count=3" -var="vm_memory_mb=4096"
virsh list --all | grep lab
virsh pool-list --all | grep lab
terraform plan -var="vm_count=2"
terraform apply -var="vm_count=2"
```

Ожидаемый вывод (примерно так):

```text
Destroy complete! Resources: 12 destroyed.
(пусто: grep ничего не нашёл)
(пусто: pool lab тоже удалён)
Plan: 9 to add, 0 to change, 0 to destroy.
Apply complete! Resources: 9 added, 0 changed, 0 destroyed.
```

Почему так: Terraform удаляет всё, что есть в state, включая pool и сеть,
поэтому `virsh vol-list lab` после destroy вернёт ошибку «pool not found» —
это и есть признак чистого удаления. Повторный `apply` скачивает base image
заново (он жил в удалённом pool).

## Упражнение 5 — Кластерный стенд: master + workers

```bash
cd ../02_examples/cluster/
terraform init
terraform apply -var="master_count=1" -var="worker_count=2"
terraform plan -var="master_count=1" -var="worker_count=3"
terraform apply -var="master_count=1" -var="worker_count=3"
terraform output worker_ips
```

Ожидаемый вывод (примерно так):

```text
Plan: 3 to add, 0 to change, 0 to destroy.
...
[
  "192.168.201.12",
  "192.168.201.13",
  "192.168.201.14",
]
```

Почему так: ресурсы workers адресуются `count.index` 0..N-1. Рост
`worker_count` с 2 до 3 только добавляет индекс `[2]` (диск, ISO, domain),
существующие `[0]` и `[1]` не меняются — replace нет. Уменьшение, наоборот,
удалит последние индексы; если нужно удалять узлы из середины, переходят на
`for_each` по именам.

## Упражнение 6 — Multi-OS: одна и та же задача на разных дистрибутивах

```bash
cd ../02_examples/multi_os/
terraform init
terraform apply
terraform output ssh_commands
# на ubuntu-24-04 и debian-12:
sudo apt-get update && sudo apt-get install -y nginx
systemctl is-active nginx
sudo ss -ltnp | grep ':80 '
# на rocky-9:
sudo dnf install -y nginx
systemctl is-active nginx
sudo systemctl enable --now nginx
sudo ss -ltnp | grep ':80 '
```

Ожидаемый вывод (примерно так):

```text
# Debian/Ubuntu:
active
LISTEN 0 511 0.0.0.0:80 0.0.0.0:* users:(("nginx",pid=1234,fd=5),...)
# Rocky:
inactive
LISTEN 0 511 0.0.0.0:80 0.0.0.0:* users:(("nginx",pid=2345,fd=6),...)
```

Почему так: пакеты Debian/Ubuntu по политике дистрибутива сразу включают и
стартуют сервис, а в RHEL-семействе сервис после установки выключен —
нужен явный `systemctl enable --now`. Конфиги тоже лежат по-разному:
`sites-available/` на Debian-семействе против `conf.d/` на Rocky. Если
на Rocky включён firewalld, порт 80 снаружи нужно открыть отдельно
(`firewall-cmd --add-service=http`).

В конце — удалить стенд из той папки, где делали `apply`:

```bash
terraform destroy
```
