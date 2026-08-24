# Tier 2 — WSL2 + VirtualBox (Windows)

На Windows лучший путь — WSL2 (Windows Subsystem for Linux 2) для
повседневной работы + VirtualBox для VM когда нужен Tier 2.

## WSL2 — установка и настройка

```powershell
# в PowerShell (Administrator)
wsl --install                          # устанавливает WSL2 + Ubuntu
wsl --set-default-version 2            # WSL2 по умолчанию

# перезагрузка обязательна после установки

# установить конкретный дистрибутив
wsl --install -d Ubuntu-24.04

# запустить
wsl
```

```bash
# внутри WSL2 — полноценный Ubuntu
# установить Docker (без Docker Desktop — через docker-ce)
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# перезапустить WSL2: exit, затем wsl

# проверить
docker compose version
```

## VirtualBox для Tier-2 VM

```bash
# в WSL2: установить Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# VirtualBox устанавливается на Windows (не в WSL2)
# https://www.virtualbox.org/wiki/Downloads
# Terraform VirtualBox provider управляет им через API
```

```hcl
# Terraform с VirtualBox provider
terraform {
  required_providers {
    virtualbox = {
      source  = "terra-farm/virtualbox"
      version = "~> 0.2"
    }
  }
}

resource "virtualbox_vm" "lab_node" {
  count  = 2
  name   = "lab-node-${count.index + 1}"
  image  = "https://app.vagrantup.com/ubuntu/boxes/jammy64/versions/20240301.0.0/providers/virtualbox.box"
  cpus   = 2
  memory = "2048 mib"
  network_adapter {
    type           = "nat"
    host_interface = "VirtualBox Host-Only Ethernet Adapter"
  }
}
```

## Альтернатива: Multipass

Multipass от Canonical — простой способ создавать Ubuntu VM на Windows/macOS/Linux.

```powershell
# Windows — установить Multipass
winget install Canonical.Multipass

# создать VM
multipass launch 24.04 --name lab-node-1 --cpus 2 --memory 2G --disk 20G
multipass launch 24.04 --name lab-node-2 --cpus 2 --memory 2G --disk 20G

# список
multipass list

# подключиться
multipass shell lab-node-1

# удалить
multipass delete lab-node-1 && multipass purge
```

## Ограничения WSL2

- WSL2 использует Hyper-V, поэтому VirtualBox на Windows 10 может
  конфликтовать (на Windows 11 совместимость улучшена)
- Нет доступа к `/dev/kvm` внутри WSL2 — KVM/libvirt недоступен
- Для большинства Tier-1 (Docker Compose) упражнений WSL2 достаточно
