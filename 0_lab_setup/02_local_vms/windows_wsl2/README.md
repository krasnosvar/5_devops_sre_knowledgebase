# Tier 2 — WSL2 + VirtualBox (Windows)

## Зачем

На Windows Linux-окружение для повседневной работы (shell, Docker,
Terraform, kubectl) даёт WSL2, а полноценные VM для Tier-2 лаб (systemd,
Ansible по SSH, kubeadm) — VirtualBox, Hyper-V или Multipass. Стенды из
[linux_kvm](../linux_kvm/) здесь напрямую не работают: им нужен libvirt.

## Пререквизиты

- Windows 10/11 с включённой аппаратной виртуализацией в BIOS/UEFI.
- Базовая работа в shell и SSH — [1_linux_and_shell](../../../1_linux_and_shell/).

## Файлы

Только этот README: отдельных `02_examples/`/`03_exercises/` нет — VM
создаются Vagrant или Multipass, а упражнения выполняются на них из
соответствующих разделов базы.

## Как проходить

1. Установить WSL2 и Docker внутри него — этого хватает для Tier 1.
2. Для Tier 2 выбрать один путь: Vagrant + VirtualBox или Multipass.
3. Поднять 1–2 VM и проверить SSH-доступ.

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

## VirtualBox + Vagrant для Tier-2 VM

Terraform-провайдер для VirtualBox (`terra-farm/virtualbox`) заброшен, на
него не стоит опираться. Для декларативного описания нескольких VM на
VirtualBox используется Vagrant: `Vagrantfile` описывает машины,
`vagrant up` их создаёт, `vagrant destroy` удаляет.

VirtualBox и Vagrant ставятся на **Windows** (не внутрь WSL2):

```powershell
winget install Oracle.VirtualBox
winget install Hashicorp.Vagrant
```

```ruby
# Vagrantfile — две Ubuntu VM в общей private-сети
Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"

  (1..2).each do |i|
    config.vm.define "lab-node-#{i}" do |node|
      node.vm.hostname = "lab-node-#{i}"
      node.vm.network "private_network", ip: "192.168.56.1#{i}"
      node.vm.provider "virtualbox" do |vb|
        vb.cpus = 2
        vb.memory = 2048
      end
    end
  end
end
```

```powershell
# в папке с Vagrantfile (PowerShell на Windows)
vagrant up              # создать и запустить VM
vagrant status
vagrant ssh lab-node-1
vagrant destroy -f      # удалить все VM стенда
```

Если включён Hyper-V (его использует WSL2), VirtualBox работает через
Hyper-V-бэкенд и может быть медленнее или нестабилен; в этом случае
проще взять Multipass (ниже) или создать VM в самом Hyper-V Manager.

## Альтернатива: Multipass

Multipass от Canonical — простой способ создавать Ubuntu VM на
Windows/macOS/Linux (на Windows использует Hyper-V или VirtualBox).

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

- WSL2 использует Hyper-V, поэтому VirtualBox на той же машине может
  работать медленнее или конфликтовать (зависит от версий Windows и
  VirtualBox).
- KVM/libvirt внутри WSL2 — не основной путь: `/dev/kvm` доступен только
  при вложенной виртуализации, и это зависит от версии Windows и
  настроек. Стенды из [linux_kvm](../linux_kvm/) здесь не рассчитаны.
- Для большинства Tier-1 (Docker Compose) упражнений WSL2 достаточно.

## Когда двигаться дальше

- В WSL2 работают `docker compose version` и `docker run --rm hello-world`.
- Можете поднять 2 VM (Vagrant или Multipass), зайти на них по SSH и
  удалить.
- Дальше — [03_local_k8s](../../03_local_k8s/).
