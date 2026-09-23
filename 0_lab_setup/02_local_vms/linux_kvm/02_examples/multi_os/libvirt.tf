# Multi-OS стенд: по одной VM на каждый дистрибутив из local.images.
# Полезно чтобы руками пощупать разницу apt/dnf, systemd-юнитов,
# путей конфигов и firewall между Ubuntu/Debian/Rocky на одинаковом "железе".
#
# Использование:
#   terraform init
#   terraform apply
#   terraform output ssh_commands
#   terraform destroy

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8.1"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

variable "vm_memory_mb" {
  type    = number
  default = 2048
}

variable "vm_vcpus" {
  type    = number
  default = 2
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/lab_key.pub"
}

# Официальные "latest" cloud-образы — ссылка не протухнет с очередным релизом.
# cloud-init сам разруливает apt/dnf в секции packages, один cloud_init.cfg
# подходит для всех трёх дистрибутивов.
locals {
  images = {
    ubuntu-24-04 = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
    debian-12    = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
    rocky-9      = "https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2"
  }
}

resource "libvirt_pool" "multi_os" {
  name = "lab-multi-os"
  type = "dir"
  target {
    path = "/var/lib/libvirt/images/lab-multi-os"
  }
}

resource "libvirt_network" "multi_os_net" {
  name      = "lab-multi-os-network"
  mode      = "nat"
  domain    = "multios.local"
  addresses = ["192.168.202.0/24"]
  dhcp { enabled = true }
  dns  { enabled = true }
}

resource "libvirt_volume" "os_image" {
  for_each = local.images
  name     = "${each.key}.qcow2"
  pool     = libvirt_pool.multi_os.name
  source   = each.value
  format   = "qcow2"
}

resource "libvirt_cloudinit_disk" "init" {
  for_each = local.images
  name     = "${each.key}-init.iso"
  pool     = libvirt_pool.multi_os.name
  user_data = templatefile("${path.module}/cloud_init.cfg", {
    hostname       = each.key
    ssh_public_key = file(pathexpand(var.ssh_public_key_path))
  })
}

resource "libvirt_domain" "vm" {
  for_each = local.images
  name     = each.key
  memory   = var.vm_memory_mb
  vcpu     = var.vm_vcpus

  cloudinit = libvirt_cloudinit_disk.init[each.key].id

  network_interface {
    network_id     = libvirt_network.multi_os_net.id
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.os_image[each.key].id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
  }
}

output "ssh_commands" {
  value = {
    for name, d in libvirt_domain.vm :
    name => "ssh -i ~/.ssh/lab_key lab@${d.network_interface[0].addresses[0]}"
  }
}
