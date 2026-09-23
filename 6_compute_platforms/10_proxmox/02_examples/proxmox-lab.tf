# Terraform: создать лабораторные VM на Proxmox
# Provider: https://github.com/bpg/terraform-provider-proxmox

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.46"
    }
  }
}

variable "proxmox_host"     { default = "192.168.1.10:8006" }
variable "proxmox_user"     { default = "root@pam" }
variable "proxmox_password" { sensitive = true }
variable "ssh_public_key"   {}
variable "vm_count"         { default = 3 }

provider "proxmox" {
  endpoint = "https://${var.proxmox_host}/"
  username = var.proxmox_user
  password = var.proxmox_password
  insecure = true
}

resource "proxmox_virtual_environment_vm" "lab" {
  count     = var.vm_count
  name      = "lab-node-${count.index + 1}"
  node_name = "pve"
  vm_id     = 200 + count.index

  clone {
    vm_id = 100    # Ubuntu 24.04 template
    full  = false  # linked clone (экономит место)
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
      ipv4 { address = "dhcp" }
    }
    user_account {
      username = "lab"
      keys     = [var.ssh_public_key]
    }
  }
}

output "vm_names" {
  value = proxmox_virtual_environment_vm.lab[*].name
}
