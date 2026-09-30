# Proxmox VE

## Что такое Proxmox VE

Proxmox Virtual Environment — open-source платформа виртуализации.
Объединяет KVM (полная виртуализация) и LXC (контейнеры) под одним UI/API.
Основан на Debian, управляется через web UI и CLI (`pvesh`, `qm`, `pct`).

Хорошо подходит для homelab и small-to-medium on-prem инфраструктуры.

## Ключевые концепции

**Node** — физический сервер Proxmox.
**Cluster** — несколько Node'ов, общее управление и HA.
**VMID** — числовой идентификатор VM или контейнера.
**Storage** — где хранятся образы дисков (local, NFS, Ceph, LVM-thin).

## CLI — управление VM

```bash
# Список VM
qm list

# Создать VM (из cloud image)
qm create 101 \
  --name ubuntu-24 \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge=vmbr0 \
  --serial0 socket \
  --vga serial0 \
  --agent enabled=1

# Импортировать cloud image как диск
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
qm importdisk 101 noble-server-cloudimg-amd64.img local-lvm

# Настроить диск и boot
qm set 101 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-101-disk-0
qm set 101 --boot c --bootdisk scsi0
qm set 101 --ide2 local-lvm:cloudinit    # cloud-init диск
qm set 101 --ipconfig0 ip=dhcp
qm set 101 --sshkeys ~/.ssh/authorized_keys

# Управление
qm start 101
qm stop 101
qm reboot 101
qm shutdown 101     # graceful (ACPI)

# Снапшот
qm snapshot 101 before-upgrade
qm rollback 101 before-upgrade
qm listsnapshot 101

# Клонировать (для шаблонов)
qm template 101                    # пометить как шаблон
qm clone 101 102 --name clone-1 --full  # полная копия
qm clone 101 103 --name linked-1        # linked clone (экономит место)
```

## CLI — управление LXC контейнерами

```bash
# Список контейнеров
pct list

# Создать контейнер
pct create 200 \
  local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst \
  --hostname mycontainer \
  --memory 512 \
  --cores 1 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --storage local-lvm \
  --rootfs local-lvm:8 \
  --unprivileged 1 \    # rootless
  --features nesting=1  # для Docker внутри LXC

# Управление
pct start 200
pct stop 200
pct enter 200          # войти внутрь контейнера
pct exec 200 -- bash -c "apt update && apt upgrade -y"
```

## Сеть — Linux bridges

```
vmbr0 — основной bridge (подключён к физическому интерфейсу)
vmbr1 — internal bridge (только между VM, без выхода наружу)

# /etc/network/interfaces
auto vmbr0
iface vmbr0 inet static
    address 192.168.1.10/24
    gateway 192.168.1.1
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0

auto vmbr1
iface vmbr1 inet static
    address 10.10.0.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    post-up echo 1 > /proc/sys/net/ipv4/ip_forward
    post-up iptables -t nat -A POSTROUTING -s '10.10.0.0/24' -o vmbr0 -j MASQUERADE
```

## Storage

```bash
# список хранилищ
pvesm status

# добавить NFS хранилище
pvesm add nfs mynfs \
  --server 192.168.1.100 \
  --export /data \
  --content images,iso,backup

# добавить LVM-Thin (для тонких томов)
pvcreate /dev/sdb
vgcreate pve-data /dev/sdb
pvesm add lvmthin pve-data-thin \
  --vgname pve-data \
  --thinpool data \
  --content images,rootdir

# Ceph (для кластера)
pveceph init --network 10.10.0.0/24
pveceph mon create
pveceph osd create /dev/sdc
pveceph pool create rbd 128
```

## HA (High Availability)

```bash
# HA доступен только в кластере (минимум 3 ноды)
ha-manager status

# добавить VM в HA
ha-manager add vm:101

# установить политику
ha-manager set vm:101 --state started --max_restart 3

# migrate VM между нодами
qm migrate 101 node2 --live        # live migration (без остановки)
qm migrate 101 node2 --online      # online migration
```

## Terraform Provider

```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.46"
    }
  }
}

provider "proxmox" {
  endpoint = "https://192.168.1.10:8006/"
  username = "root@pam"
  password = var.proxmox_password
  insecure = true   # отключить проверку TLS для self-signed cert
}

resource "proxmox_virtual_environment_vm" "lab_node" {
  count     = 3
  name      = "lab-node-${count.index + 1}"
  node_name = "pve"
  vm_id     = 200 + count.index

  clone {
    vm_id = 101    # шаблон Ubuntu 24.04
    full  = false  # linked clone
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 2048
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
    user_account {
      username = "lab"
      keys     = [var.ssh_public_key]
    }
  }
}
```
