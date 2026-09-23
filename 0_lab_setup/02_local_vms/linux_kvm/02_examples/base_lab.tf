# Базовый стенд: 1-3 VM на KVM через Terraform libvirt provider
# Зависимости: terraform, libvirt, qemu-kvm
#
# Использование:
#   terraform init
#   terraform apply -var="vm_count=3"
#   ssh -i ~/.ssh/lab_key lab@$(terraform output -raw vm_ips | head -1)
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

variable "vm_count" {
  type    = number
  default = 1
}

variable "vm_memory_mb" {
  type    = number
  default = 2048
}

variable "vm_vcpus" {
  type    = number
  default = 2
}

variable "vm_disk_gb" {
  type    = number
  default = 20
}

variable "base_image_url" {
  type    = string
  default = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/lab_key.pub"
}

# ── Storage pool ─────────────────────────────────────────────────────────────
resource "libvirt_pool" "lab" {
  name = "lab"
  type = "dir"
  target {
    path = "/var/lib/libvirt/images/lab"
  }
}

# ── Base image (скачивается один раз, все VM используют как backing) ──────────
resource "libvirt_volume" "base_image" {
  name   = "ubuntu-24.04-base.qcow2"
  pool   = libvirt_pool.lab.name
  source = var.base_image_url
  format = "qcow2"
}

# ── Диски VM (delta поверх base image) ───────────────────────────────────────
resource "libvirt_volume" "vm_disk" {
  count          = var.vm_count
  name           = "lab-node-${count.index + 1}.qcow2"
  pool           = libvirt_pool.lab.name
  base_volume_id = libvirt_volume.base_image.id
  size           = var.vm_disk_gb * 1024 * 1024 * 1024
  format         = "qcow2"
}

# ── cloud-init ────────────────────────────────────────────────────────────────
# templatefile() — встроенная функция Terraform (0.12+), отдельный
# provider "hashicorp/template" для этого не нужен (он давно в архиве и
# не обновляется — не тащи его в новые стенды).
resource "libvirt_cloudinit_disk" "vm_init" {
  count = var.vm_count
  name  = "lab-node-${count.index + 1}-init.iso"
  pool  = libvirt_pool.lab.name
  user_data = templatefile("${path.module}/cloud_init.cfg", {
    hostname       = "lab-node-${count.index + 1}"
    ssh_public_key = file(pathexpand(var.ssh_public_key_path))
  })
}

# ── Сеть (NAT, 192.168.122.0/24) ─────────────────────────────────────────────
resource "libvirt_network" "lab_net" {
  name      = "lab-network"
  mode      = "nat"
  domain    = "lab.local"
  addresses = ["192.168.200.0/24"]
  dhcp { enabled = true }
  dns  { enabled = true }
}

# ── VM ────────────────────────────────────────────────────────────────────────
resource "libvirt_domain" "lab_node" {
  count  = var.vm_count
  name   = "lab-node-${count.index + 1}"
  memory = var.vm_memory_mb
  vcpu   = var.vm_vcpus

  cloudinit = libvirt_cloudinit_disk.vm_init[count.index].id

  network_interface {
    network_id     = libvirt_network.lab_net.id
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.vm_disk[count.index].id
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

# ── Outputs ───────────────────────────────────────────────────────────────────
output "vm_names" {
  value = libvirt_domain.lab_node[*].name
}

output "vm_ips" {
  value = [for d in libvirt_domain.lab_node : d.network_interface[0].addresses[0]]
}

output "ssh_commands" {
  value = [
    for i, d in libvirt_domain.lab_node :
    "ssh -i ~/.ssh/lab_key lab@${d.network_interface[0].addresses[0]}"
  ]
}
