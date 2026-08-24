# Tier 2 — KVM + libvirt + Terraform (Linux)

Рекомендуемый Tier-2 сетап для Linux. Позволяет создавать VM командой
`terraform apply` и сразу подключаться по SSH.

## Зависимости

```bash
# Fedora / RHEL
sudo dnf install -y qemu-kvm libvirt libvirt-daemon-kvm virt-install \
  libguestfs-tools terraform

# Ubuntu / Debian
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients \
  bridge-utils virt-manager

# запустить libvirtd
sudo systemctl enable --now libvirtd

# добавить себя в группу (нужен relogin)
sudo usermod -aG libvirt,kvm $USER

# сгенерировать SSH ключ для лабы (если нет)
ssh-keygen -t ed25519 -f ~/.ssh/lab_key -N ""

# проверить KVM
kvm-ok || grep -E 'vmx|svm' /proc/cpuinfo | head -1

# установить Terraform libvirt provider (автоматически при terraform init)
```

## Быстрый старт

```bash
cd 02_examples/
terraform init
terraform apply -var="vm_count=1"   # поднять 1 VM
terraform output ssh_commands       # получить команду для подключения
# ... работаем ...
terraform destroy
```

## Теория

- [01_theory/kvm_libvirt_arch.md](01_theory/kvm_libvirt_arch.md) — KVM/QEMU/libvirt,
  сетевые режимы, storage, cloud-init.

## Стенды

- [02_examples/base_lab.tf](02_examples/base_lab.tf) — базовый шаблон:
  1–N VM, backing image, cloud-init, NAT-сеть.
