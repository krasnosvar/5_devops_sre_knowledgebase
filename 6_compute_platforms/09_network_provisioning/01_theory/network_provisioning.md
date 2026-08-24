# Network Provisioning — сетевая инфраструктура серверов

## Bonding / Teaming — агрегация каналов

```bash
# Bonding — объединить несколько физических интерфейсов в один логический
# Режимы:
# mode=0 (balance-rr): round-robin, балансировка нагрузки
# mode=1 (active-backup): один активный, другие резервные (HA)
# mode=4 (802.3ad LACP): агрегация через протокол с коммутатором (нужна поддержка свитча)

# Создать bond через NetworkManager
nmcli con add type bond con-name bond0 ifname bond0 mode active-backup
nmcli con add type ethernet con-name bond0-slave1 ifname eth0 master bond0
nmcli con add type ethernet con-name bond0-slave2 ifname eth1 master bond0
nmcli con modify bond0 ipv4.addresses 10.0.0.1/24 ipv4.method manual

# Проверить состояние
cat /proc/net/bonding/bond0
ip link show bond0
```

## VLAN — виртуальные сети через 802.1q

```bash
# Создать VLAN интерфейс (VLAN 100 поверх eth0)
ip link add link eth0 name eth0.100 type vlan id 100
ip addr add 10.100.0.1/24 dev eth0.100
ip link set eth0.100 up

# Через NetworkManager
nmcli con add type vlan con-name vlan100 ifname eth0.100 \
  dev eth0 id 100 \
  ipv4.addresses 10.100.0.1/24 \
  ipv4.method manual

# Через /etc/network/interfaces (Debian)
auto eth0.100
iface eth0.100 inet static
  address 10.100.0.1
  netmask 255.255.255.0
  vlan_raw_device eth0

# Trunk порт на коммутаторе пропускает все VLAN
# Access порт — только один VLAN (для сервера с одним NIC)
```

## Jumbo Frames (MTU 9000)

```bash
# Стандартный MTU: 1500 байт
# Jumbo frames: 9000 байт — меньше overhead для больших передач
# Важно для: хранилища (NFS, iSCSI), Ceph, высоконагруженных сетей

# Изменить MTU
ip link set eth0 mtu 9000

# Постоянно через NetworkManager
nmcli con modify eth0 ethernet.mtu 9000

# Проверить что jumbo frames работают end-to-end
ping -M do -s 8972 10.0.0.2   # -M do = Don't Fragment, -s = payload size
# 8972 + 28 (IP+ICMP header) = 9000 = MTU

# ВНИМАНИЕ: весь путь должен поддерживать jumbo frames
# Коммутаторы, роутеры, виртуальные интерфейсы — все должны иметь MTU >= 9000
```

## Network Booting (PXE)

```bash
# Цепочка: DHCP → TFTP → bootloader → kernel

# dnsmasq — DHCP + TFTP сервер
# /etc/dnsmasq.conf
interface=eth0
dhcp-range=192.168.1.100,192.168.1.200,1h
dhcp-boot=pxelinux.0,192.168.1.1,192.168.1.1  # bootloader,hostname,tftp-server
enable-tftp
tftp-root=/var/lib/tftpboot

# Настроить DHCP опции для UEFI (если серверы UEFI)
dhcp-match=set:efi-x86_64,option:client-arch,7
dhcp-boot=tag:efi-x86_64,grubx64.efi

# Подготовить TFTP
mkdir -p /var/lib/tftpboot
cp /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot/
cp /boot/vmlinuz /var/lib/tftpboot/
cp /boot/initrd.img /var/lib/tftpboot/

systemctl enable --now dnsmasq
```

## Open vSwitch (OVS) — SDN для on-prem

```bash
# OVS — программируемый виртуальный коммутатор
# Используется в: OpenStack, oVirt, on-prem облаках
apt install openvswitch-switch

# Создать bridge
ovs-vsctl add-br br0

# Добавить физический порт
ovs-vsctl add-port br0 eth0

# Создать VLAN порт для VM
ovs-vsctl add-port br0 veth0 tag=100

# Статус
ovs-vsctl show
ovs-ofctl dump-flows br0   # OpenFlow правила
```

## DHCP, DNS и IPAM

```bash
# ISC DHCP Server
# /etc/dhcp/dhcpd.conf
subnet 10.0.0.0 netmask 255.255.255.0 {
  range 10.0.0.100 10.0.0.200;
  option routers 10.0.0.1;
  option domain-name-servers 10.0.0.1;
  default-lease-time 86400;

  # Статический lease по MAC адресу
  host web-server {
    hardware ethernet 00:11:22:33:44:55;
    fixed-address 10.0.0.10;
    option host-name "web-server";
  }
}

# PowerDNS + phpIPAM — IPAM (IP Address Management)
# Centralized management: кто использует какой IP
```

## Terraform для сетей

```hcl
# Создать VLAN через Proxmox provider
resource "proxmox_virtual_environment_network_linux_vlan" "vlan100" {
  node_name = "pve"
  name      = "vlan100"
  vlan      = 100
  interface = "eno1"
  address   = "10.100.0.1/24"
}

# AWS: VPC + суbnets через Terraform
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  
  cidr = "10.0.0.0/16"
  azs  = ["eu-central-1a", "eu-central-1b"]
  
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  
  enable_nat_gateway = true
  single_nat_gateway = false   # по HA: NAT Gateway в каждой AZ
}
```
