# Terraform: 3 ноды на Hetzner Cloud
# Запуск: terraform apply -var="hcloud_token=YOUR_TOKEN"

terraform {
  required_providers {
    hcloud = { source = "hetznercloud/hcloud", version = "~> 1.47" }
  }
}

variable "hcloud_token" { sensitive = true }
variable "node_count"   { default = 3 }
variable "server_type"  { default = "cx22" }   # 2vCPU, 4GB, ~€4/мес

provider "hcloud" { token = var.hcloud_token }

resource "hcloud_ssh_key" "lab" {
  name       = "lab-key"
  public_key = file("~/.ssh/lab_key.pub")
}

resource "hcloud_network" "lab" {
  name     = "lab-network"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "lab" {
  network_id   = hcloud_network.lab.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

resource "hcloud_server" "node" {
  count       = var.node_count
  name        = "lab-node-${count.index + 1}"
  server_type = var.server_type
  image       = "ubuntu-24.04"
  location    = "fsn1"
  ssh_keys    = [hcloud_ssh_key.lab.id]

  network {
    network_id = hcloud_network.lab.id
    ip         = "10.0.1.${10 + count.index}"
  }

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -q
    apt-get install -y -q curl git jq
    hostnamectl set-hostname lab-node-${count.index + 1}
  EOF
}

output "public_ips"  { value = hcloud_server.node[*].ipv4_address }
output "private_ips" { value = [for s in hcloud_server.node : s.network[*].ip[0]] }
output "ssh_commands" {
  value = [for s in hcloud_server.node : "ssh -i ~/.ssh/lab_key root@${s.ipv4_address}"]
}
