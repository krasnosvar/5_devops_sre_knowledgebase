# Кластерный стенд: N master + M worker VM на KVM через Terraform libvirt provider
# Готовит только "голые" VM с правильными hostname и сетью — kubeadm/ansible
# накатывается отдельно (см. 3_kubernetes/ и 4_iac/06_ansible/).
#
# Использование:
#   terraform init
#   terraform apply -var="master_count=1" -var="worker_count=2"
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

variable "master_count" {
  type    = number
  default = 1
}

variable "worker_count" {
  type    = number
  default = 2
}

variable "master_memory_mb" {
  type    = number
  default = 2048
}

variable "worker_memory_mb" {
  type    = number
  default = 4096
}

variable "master_vcpus" {
  type    = number
  default = 2
}

variable "worker_vcpus" {
  type    = number
  default = 2
}

variable "base_image_url" {
  type    = string
  default = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/lab_key.pub"
}

# ── Storage pool (свой, чтобы не пересекаться с base_lab.tf) ─────────────────
resource "libvirt_pool" "cluster" {
  name = "lab-cluster"
  type = "dir"
  target {
    path = "/var/lib/libvirt/images/lab-cluster"
  }
}

resource "libvirt_volume" "base_image" {
  name   = "ubuntu-24.04-base.qcow2"
  pool   = libvirt_pool.cluster.name
  source = var.base_image_url
  format = "qcow2"
}

# ── Сеть (свой NAT-сегмент под кластер) ──────────────────────────────────────
resource "libvirt_network" "cluster_net" {
  name      = "lab-cluster-network"
  mode      = "nat"
  domain    = "k8s.local"
  addresses = ["192.168.201.0/24"]
  dhcp { enabled = true }
  dns  { enabled = true }
}

# ── Masters ───────────────────────────────────────────────────────────────────
resource "libvirt_volume" "master_disk" {
  count          = var.master_count
  name           = "k8s-master-${count.index + 1}.qcow2"
  pool           = libvirt_pool.cluster.name
  base_volume_id = libvirt_volume.base_image.id
  format         = "qcow2"
}

# templatefile() — встроенная функция Terraform (0.12+), не нужен провайдер
# hashicorp/template (он давно archived и не обновляется)
resource "libvirt_cloudinit_disk" "master_init" {
  count = var.master_count
  name  = "k8s-master-${count.index + 1}-init.iso"
  pool  = libvirt_pool.cluster.name
  user_data = templatefile("${path.module}/../cloud_init.cfg", {
    hostname       = "k8s-master-${count.index + 1}"
    ssh_public_key = file(pathexpand(var.ssh_public_key_path))
  })
}

resource "libvirt_domain" "master" {
  count  = var.master_count
  name   = "k8s-master-${count.index + 1}"
  memory = var.master_memory_mb
  vcpu   = var.master_vcpus

  cloudinit = libvirt_cloudinit_disk.master_init[count.index].id

  network_interface {
    network_id     = libvirt_network.cluster_net.id
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.master_disk[count.index].id
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

# ── Workers ───────────────────────────────────────────────────────────────────
resource "libvirt_volume" "worker_disk" {
  count          = var.worker_count
  name           = "k8s-worker-${count.index + 1}.qcow2"
  pool           = libvirt_pool.cluster.name
  base_volume_id = libvirt_volume.base_image.id
  format         = "qcow2"
}

resource "libvirt_cloudinit_disk" "worker_init" {
  count = var.worker_count
  name  = "k8s-worker-${count.index + 1}-init.iso"
  pool  = libvirt_pool.cluster.name
  user_data = templatefile("${path.module}/../cloud_init.cfg", {
    hostname       = "k8s-worker-${count.index + 1}"
    ssh_public_key = file(pathexpand(var.ssh_public_key_path))
  })
}

resource "libvirt_domain" "worker" {
  count  = var.worker_count
  name   = "k8s-worker-${count.index + 1}"
  memory = var.worker_memory_mb
  vcpu   = var.worker_vcpus

  cloudinit = libvirt_cloudinit_disk.worker_init[count.index].id

  network_interface {
    network_id     = libvirt_network.cluster_net.id
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.worker_disk[count.index].id
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
output "master_ips" {
  value = [for d in libvirt_domain.master : d.network_interface[0].addresses[0]]
}

output "worker_ips" {
  value = [for d in libvirt_domain.worker : d.network_interface[0].addresses[0]]
}

output "ssh_commands" {
  value = concat(
    [for d in libvirt_domain.master : "ssh -i ~/.ssh/lab_key lab@${d.network_interface[0].addresses[0]}  # ${d.name}"],
    [for d in libvirt_domain.worker : "ssh -i ~/.ssh/lab_key lab@${d.network_interface[0].addresses[0]}  # ${d.name}"],
  )
}
