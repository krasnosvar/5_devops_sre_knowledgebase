# 11. VMware vSphere

## Зачем
vSphere по-прежнему работает во многих крупных компаниях, и инженеру
нужно уметь автоматизировать его (govc, Terraform) и планировать уход с
него. После покупки VMware компанией Broadcom лицензирование перешло на
подписку и бандлы, поэтому вопрос «оставаться или мигрировать на KVM,
Proxmox или Kubernetes с KubeVirt» стал практическим.

## Пререквизиты
- [10_proxmox](../10_proxmox/) — понятия гипервизора, шаблонов, клонов и
  HA на открытой платформе.
- [5_iac/01_terraform_core](../../5_iac/01_terraform_core/) — для
  Terraform vSphere provider.
- [4_kubernetes](../../4_kubernetes/) — для разделов о миграции и
  KubeVirt.

## Файлы
- [01_theory/vmware_vsphere.md](./01_theory/vmware_vsphere.md) —
  архитектура (vCenter, ESXi, vSAN, NSX-T), изменения лицензирования
  после покупки Broadcom, CLI `govc`, Terraform vSphere provider, миграция
  на KVM/Kubernetes (virt-v2v, Konveyor), KubeVirt.

Без примеров и упражнений: для лабы нужен лицензированный vSphere
(vCenter + ESXi), который сложно получить для учёбы.

## Как проходить
1. Прочитать теорию.
2. Сопоставить понятия vSphere с Proxmox: vCenter ↔ кластер Proxmox,
   datastore ↔ storage, шаблон ↔ шаблон.
3. Если есть доступ к vSphere: выполнить читающие команды `govc` и
   `terraform plan` для примера из теории.

## Когда двигаться дальше
- Можете объяснить роли vCenter, ESXi, vSAN и NSX.
- Можете перечислить шаги миграции VM с vSphere на KVM через virt-v2v.
- Можете объяснить, когда VM лучше перенести в KubeVirt, а когда
  переписать в контейнеры.

Дальше — [12_platform_comparison](../12_platform_comparison/).
