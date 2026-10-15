# Tier 2 — KVM + libvirt + Terraform (Linux)

## Зачем

Рекомендуемый Tier-2 сетап для Linux: «настоящие» VM со своим ядром,
systemd и сетью, которые создаются командой `terraform apply` и сразу
доступны по SSH. Нужен там, где контейнеров мало: Ansible по SSH, kubeadm,
troubleshooting на уровне ОС, многоузловые стенды.

## Пререквизиты

- Linux-хост с аппаратной виртуализацией (Intel VT-x / AMD-V) и 8+ GB RAM.
- Базовая работа в shell и SSH — подробно в
  [1_linux_and_shell](../../../1_linux_and_shell/).

> **Забегание вперёд.** Здесь используется Terraform, который подробно
> разбирается в [5_iac/01_terraform_core](../../../5_iac/01_terraform_core/).
> Для этой темы достаточно: `terraform init` (скачать провайдер),
> `terraform plan` (посмотреть, что изменится), `terraform apply`
> (создать), `terraform output` (получить IP) и `terraform destroy`
> (удалить). Если Terraform ещё не освоен — VM можно создать руками через
> `virt-install`/`virt-manager`, а к стендам вернуться позже.

## Зависимости

```bash
# Fedora / RHEL
sudo dnf install -y qemu-kvm libvirt libvirt-daemon-kvm virt-install \
  libguestfs-tools terraform

# Ubuntu / Debian
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients \
  bridge-utils virt-manager
# Terraform на Debian/Ubuntu ставится из репозитория HashiCorp:
# https://developer.hashicorp.com/terraform/install

# запустить libvirtd
sudo systemctl enable --now libvirtd

# добавить себя в группу (нужен relogin)
sudo usermod -aG libvirt,kvm $USER

# сгенерировать SSH ключ для лабы (если нет)
ssh-keygen -t ed25519 -f ~/.ssh/lab_key -N ""

# проверить KVM
kvm-ok || grep -E 'vmx|svm' /proc/cpuinfo | head -1

# Terraform libvirt provider скачивается автоматически при terraform init
```

## Быстрый старт

```bash
cd 02_examples/
terraform init
terraform plan -var="vm_count=1"
terraform apply -var="vm_count=1"   # поднять 1 VM
terraform output ssh_commands       # получить команду для подключения
# ... работаем ...
terraform destroy -var="vm_count=1"
```

## Файлы

- [01_theory/kvm_libvirt_arch.md](01_theory/kvm_libvirt_arch.md) —
  KVM/QEMU/libvirt, сетевые режимы, storage, cloud-init.
- [02_examples/base_lab.tf](02_examples/base_lab.tf) — базовый шаблон:
  1–N одинаковых VM, backing image, cloud-init, NAT-сеть.
- [02_examples/cluster/](02_examples/cluster/) — master + workers для будущего
  k8s (kubeadm/ansible накатывается уже поверх, см.
  [4_kubernetes](../../../4_kubernetes/) и
  [5_iac/06_ansible](../../../5_iac/06_ansible/)).
- [02_examples/multi_os/](02_examples/multi_os/) — по одной VM на
  Ubuntu 24.04 / Debian 12 / Rocky 9, чтобы пощупать разницу apt/dnf на
  одинаковом стенде.
- [02_examples/broken/](02_examples/broken/) — 3 намеренно сломанные VM для
  практики troubleshooting (лог не пишется / CPU 100% / 504 на health-чеке).
- [03_exercises/README.md](03_exercises/README.md) — 7 упражнений, 🖥 Tier 2.
- [04_exercises_answers/](04_exercises_answers/) — ответы:
  [answers.md](04_exercises_answers/answers.md) (01–06) и
  [broken-vm-answers.md](04_exercises_answers/broken-vm-answers.md) (07).

## Как проходить

1. Прочитать теорию — что такое KVM, QEMU, libvirt и cloud-init.
2. Установить зависимости и поднять одну VM через «Быстрый старт».
3. Сделать упражнения 01–06 по порядку, затем 07 (troubleshooting).
4. Сверяться с ответами только после собственной попытки; в конце каждого
   упражнения — `terraform destroy`.

## Когда двигаться дальше

- Можете поднять и удалить стенд из N VM и подключиться к ним по SSH.
- Можете по `terraform plan` сказать, будет ли VM пересоздана.
- Можете откатить VM на snapshot через `virsh`.
- Дальше — [03_local_k8s](../../03_local_k8s/) (или другая платформа в
  [02_local_vms](../), если работаете не на Linux).
