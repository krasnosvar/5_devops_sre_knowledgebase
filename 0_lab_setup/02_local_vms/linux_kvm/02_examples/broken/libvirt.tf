# Стенд для практики troubleshooting: 3 VM, в каждой намеренно сломан один
# типовой сценарий (см. 03_exercises/README.md — что именно нужно найти,
# и 04_exercises_answers/ — разбор и фикс, если застрял).
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
  default = 1024
}

variable "vm_vcpus" {
  type    = number
  default = 1
}

variable "base_image_url" {
  type    = string
  default = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/lab_key.pub"
}

# имя сценария → cloud-init файл с уже вшитым багом
locals {
  scenarios = {
    broken-logs = "cloud_init_logs.cfg"
    broken-cpu  = "cloud_init_cpu.cfg"
    broken-504  = "cloud_init_504.cfg"
  }
}

resource "libvirt_pool" "broken" {
  name = "lab-broken"
  type = "dir"
  target {
    path = "/var/lib/libvirt/images/lab-broken"
  }
}

resource "libvirt_network" "broken_net" {
  name      = "lab-broken-network"
  mode      = "nat"
  domain    = "broken.local"
  addresses = ["192.168.203.0/24"]
  dhcp { enabled = true }
  dns  { enabled = true }
}

resource "libvirt_volume" "base_image" {
  name   = "ubuntu-24.04-base.qcow2"
  pool   = libvirt_pool.broken.name
  source = var.base_image_url
  format = "qcow2"
}

resource "libvirt_volume" "vm_disk" {
  for_each       = local.scenarios
  name           = "${each.key}.qcow2"
  pool           = libvirt_pool.broken.name
  base_volume_id = libvirt_volume.base_image.id
  format         = "qcow2"
}

resource "libvirt_cloudinit_disk" "init" {
  for_each = local.scenarios
  name     = "${each.key}-init.iso"
  pool     = libvirt_pool.broken.name
  user_data = templatefile("${path.module}/${each.value}", {
    ssh_public_key = file(pathexpand(var.ssh_public_key_path))
  })
}

resource "libvirt_domain" "vm" {
  for_each = local.scenarios
  name     = each.key
  memory   = var.vm_memory_mb
  vcpu     = var.vm_vcpus

  cloudinit = libvirt_cloudinit_disk.init[each.key].id

  network_interface {
    network_id     = libvirt_network.broken_net.id
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.vm_disk[each.key].id
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
