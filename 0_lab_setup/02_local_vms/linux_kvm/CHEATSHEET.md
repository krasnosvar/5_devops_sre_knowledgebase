# KVM + QEMU + libvirt — шпаргалка

Подробности и объяснения — в
[kvm_libvirt_arch.md](./01_theory/kvm_libvirt_arch.md).
⚠️ — опасная команда или частая ловушка.

## Кто за что отвечает

| Слой | Что делает | Где смотреть |
| :--- | :--- | :--- |
| KVM | модуль ядра, аппаратная виртуализация (VT-x / AMD-V) | `/dev/kvm`, `lsmod \| grep kvm` |
| QEMU | процесс на VM, эмулирует диск/сеть/BIOS | `ps -ef \| grep qemu` |
| libvirtd | API (UNIX-сокет): VM, сети, storage pools | `systemctl status libvirtd` |
| virsh / virt-manager / Terraform libvirt provider | клиенты libvirt | — |

## Подготовка хоста

| Задача | Команда |
| :--- | :--- |
| Есть ли аппаратная виртуализация | `grep -cE 'vmx\|svm' /proc/cpuinfo` (0 = нет) |
| Проверка хоста целиком | `virt-host-validate qemu` |
| Запустить libvirtd | `sudo systemctl enable --now libvirtd` |
| Работать без `sudo` (нужен relogin) | `sudo usermod -aG libvirt,kvm $USER` |
| SSH-ключ для лабы | `ssh-keygen -t ed25519 -f ~/.ssh/lab_key -N ""` |
| Смотреть системные VM, а не session ⚠️ | `export LIBVIRT_DEFAULT_URI=qemu:///system` |

## virsh: VM

| Задача | Команда |
| :--- | :--- |
| Все VM, включая выключенные | `virsh list --all` |
| Включить / корректно выключить | `virsh start <vm>` / `virsh shutdown <vm>` |
| Перезагрузить | `virsh reboot <vm>` |
| «Выдернуть питание» ⚠️ без shutdown ОС | `virsh destroy <vm>` |
| Удалить VM вместе с дисками ⚠️ | `virsh undefine <vm> --remove-all-storage` |
| CPU, RAM, состояние | `virsh dominfo <vm>` |
| IP-адрес VM | `virsh domifaddr <vm>` |
| Серийная консоль (выход: `Ctrl+]`) | `virsh console <vm>` |
| XML-описание / правка | `virsh dumpxml <vm>` / `virsh edit <vm>` |

## virsh: снапшоты, сети, storage

| Задача | Команда |
| :--- | :--- |
| Создать снапшот | `virsh snapshot-create-as <vm> before-experiment` |
| Список / откат / удаление | `virsh snapshot-list <vm>`<br>`virsh snapshot-revert <vm> before-experiment`<br>`virsh snapshot-delete <vm> before-experiment` |
| Сети libvirt | `virsh net-list --all` |
| Аренды DHCP в NAT-сети | `virsh net-dhcp-leases default` |
| Storage pools / тома в pool | `virsh pool-list --all` / `virsh vol-list <pool>` |

## Сетевые режимы

| Режим | Адрес VM | Видна из LAN | Когда |
| :--- | :--- | :--- | :--- |
| NAT (`virbr0`, по умолчанию) | `192.168.122.0/24` | нет, только с хоста | большинство лаб |
| Bridge | от DHCP роутера | да | нужен доступ извне |
| Isolated | внутренняя сеть | нет, и наружу тоже нет | закрытые стенды |

## Диски qcow2

| Задача | Команда |
| :--- | :--- |
| Дельта-диск поверх базового образа | `qemu-img create -f qcow2 -b base.qcow2 -F qcow2 vm1.qcow2` |
| Формат, размер, цепочка backing | `qemu-img info --backing-chain vm1.qcow2` |
| Увеличить виртуальный размер | `qemu-img resize vm1.qcow2 +10G` |
| ⚠️ | базовый образ не менять, пока на нём висят дельты — они сломаются |

## cloud-init (внутри VM)

| Задача | Команда |
| :--- | :--- |
| Дождаться окончания первичной настройки | `cloud-init status --wait` |
| Вывод `runcmd`/`packages` | `/var/log/cloud-init-output.log` |
| Подробный лог модулей | `/var/log/cloud-init.log` |
| Проверить синтаксис user-data | `cloud-init schema --config-file cloud_init.cfg` |

## Terraform-стенд

| Задача | Команда |
| :--- | :--- |
| Скачать провайдер | `terraform init` |
| План / создать N VM | `terraform plan -var="vm_count=3"`<br>`terraform apply -var="vm_count=3"` |
| IP и команды SSH | `terraform output vm_ips` / `terraform output ssh_commands` |
| Удалить стенд | `terraform destroy` |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| `virsh list --all` пуст, хотя VM есть | смотрите `qemu:///session` — нужен `qemu:///system` |
| VM очень медленная | нет KVM, чистая эмуляция: `/dev/kvm`, BIOS VT-x/AMD-V |
| Нет IP у VM | `virsh net-dhcp-leases default`, cloud-init не отработал |
| SSH по ключу не пускает | `virsh console <vm>`, `/var/log/cloud-init.log` |
| `apply` пересоздаёт VM | смотрите в `plan` поля с `forces replacement` |

> Проверка: подкоманды и флаги `virsh`, `qemu-img`, `virt-host-validate`
> сверены с `--help` локально; не проверено: `cloud-init` (внутри VM),
> `terraform` против реального libvirt.
