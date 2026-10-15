# 10. Proxmox VE

## Зачем
Proxmox VE — open-source платформа виртуализации на базе KVM и LXC с
кластером, HA, общим хранилищем и API. Это частый выбор для homelab и
небольших on-prem инсталляций, а после изменений лицензирования VMware —
и как замена vSphere. Тема даёт CLI (`qm`, `pct`, `pvesm`, `ha-manager`) и
автоматизацию через Terraform.

## Пререквизиты
- [0_lab_setup/02_local_vms](../../0_lab_setup/02_local_vms/) — KVM и
  cloud-образы на локальной машине.
- [09_network_provisioning](../09_network_provisioning/) — Linux bridges,
  VLAN.
- [5_iac/01_terraform_core](../../5_iac/01_terraform_core/) — для примера
  с Terraform-провайдером.

## Файлы
- [01_theory/proxmox.md](./01_theory/proxmox.md) — архитектура и
  понятия, VM через `qm` (импорт cloud-образа через `qm disk import`,
  снапшоты, шаблоны, клоны), LXC через `pct`, сеть на Linux bridges,
  хранилища (NFS, LVM-thin, Ceph), HA и миграция, Terraform-провайдер.
- [02_examples/proxmox-lab.tf](./02_examples/proxmox-lab.tf) — Terraform
  (провайдер `bpg/proxmox`): N лабораторных VM, клонированных из шаблона,
  с cloud-init. Требует хост Proxmox и шаблон с ID 100.

Без упражнений с ответами: для лабы нужен хост Proxmox (🖥 Tier 2 —
отдельный сервер или вложенная виртуализация в VM).

## Как проходить
1. Прочитать теорию.
2. Если есть хост Proxmox: создать шаблон из cloud-образа по шагам из
   раздела «CLI — управление VM».
3. Скопировать `proxmox-lab.tf`, выполнить `terraform init`,
   `terraform plan` и, после проверки плана, `terraform apply`; в конце —
   `terraform destroy`.

## Когда двигаться дальше
- Можете создать VM из cloud-образа и превратить её в шаблон без
  подсказки.
- Можете объяснить, чем linked clone отличается от full clone и чем
  online-миграция отличается от offline.
- Понимаете, почему для HA нужно минимум 3 ноды (кворум).

Дальше — [11_vmware_vsphere](../11_vmware_vsphere/).
