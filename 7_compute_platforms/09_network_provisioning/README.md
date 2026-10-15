# 09. Network Provisioning

## Зачем
Сервер с одной сетевой картой и MTU 1500 — это не продакшн. Bare metal
обычно подключают двумя линками в bond, разделяют трафик по VLAN,
включают jumbo frames для хранилища и раздают адреса через DHCP/IPAM.
Ошибки здесь дают самые неприятные инциденты: всё работает, кроме
больших пакетов или одного VLAN.

## Пререквизиты
- [1_linux_and_shell/06_networking_basics](../../1_linux_and_shell/06_networking_basics/)
  — `ip`, интерфейсы, маршруты в Linux.
- [2_networking/00_osi_and_tcpip](../../2_networking/00_osi_and_tcpip/) —
  L2/L3, MTU, фрагментация.
- [07_os_provisioning](../07_os_provisioning/) — PXE и dnsmasq.
- [5_iac/01_terraform_core](../../5_iac/01_terraform_core/) — для раздела
  «Terraform для сетей».

## Файлы
- [01_theory/network_provisioning.md](./01_theory/network_provisioning.md)
  — bonding (active-backup, LACP), VLAN 802.1q, jumbo frames и проверка
  MTU, сетевая загрузка, Open vSwitch, DHCP/DNS/IPAM, Terraform для сетей.

Без упражнений с ответами. Bonding, VLAN и MTU можно отработать
самостоятельно на 🖥 Tier 2 — VM с несколькими сетевыми интерфейсами в
[0_lab_setup/02_local_vms](../../0_lab_setup/02_local_vms/); LACP требует
поддержки на коммутаторе.

## Как проходить
1. Прочитать теорию.
2. На VM с двумя интерфейсами собрать bond в режиме active-backup,
   отключить один линк и убедиться, что связь осталась
   (`cat /proc/net/bonding/bond0`).
3. Поднять VLAN-интерфейс и проверить jumbo frames командой
   `ping -M do -s 8972` между двумя VM.

## Когда двигаться дальше
- Можете объяснить разницу между active-backup и 802.3ad и что для
  каждого нужно от коммутатора.
- Можете объяснить, почему jumbo frames должны быть включены на всём
  пути, и проверить это одной командой.
- Можете объяснить разницу между trunk- и access-портом.

Дальше — [10_proxmox](../10_proxmox/): виртуализация поверх подготовленного
железа и сети.
