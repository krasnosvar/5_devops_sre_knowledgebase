# 02. Локальные VM (Tier 2)

## Зачем

Docker-контейнеры делят ядро хоста и обычно не запускают systemd, поэтому
часть задач на них не отработать: Ansible по SSH, kubeadm на «голых»
узлах, troubleshooting на уровне ОС, многоузловые стенды. Для этого нужны
локальные VM — бесплатно и без облачного аккаунта.

## Пререквизиты

- [01_docker_compose](../01_docker_compose/) — Tier 1 уже работает.
- Базовая работа в shell и SSH — [1_linux_and_shell](../../1_linux_and_shell/).

> **Забегание вперёд.** На Linux стенды описаны в Terraform, который
> подробно разбирается в [5_iac/01_terraform_core](../../5_iac/01_terraform_core/).
> Для этой темы достаточно: `terraform init`, `terraform plan`,
> `terraform apply`, `terraform output`, `terraform destroy`. Если
> Terraform ещё не освоен — эту часть можно пропустить и вернуться к ней
> позже.

## Файлы

Выберите одну платформу:

- [linux_kvm/](./linux_kvm/) — KVM + QEMU + libvirt + Terraform
  (рекомендуемый Linux-сетап): теория, стенды, 7 упражнений с ответами.
- [macos_orbstack/](./macos_orbstack/) — OrbStack на macOS (Intel и Apple
  Silicon), без отдельных упражнений.
- [windows_wsl2/](./windows_wsl2/) — WSL2 для повседневной работы +
  Vagrant/VirtualBox или Multipass для VM, без отдельных упражнений.

## Как проходить

1. Открыть README своей платформы и поднять одну VM.
2. На Linux — пройти упражнения `linux_kvm/03_exercises/`.
3. Удалить стенд, когда он не нужен (`terraform destroy`, `orb delete`,
   `vagrant destroy`, `multipass delete`).

## Когда двигаться дальше

- Можете за несколько минут поднять 2–3 VM и зайти на них по SSH.
- Можете удалить стенд целиком, не оставив мусора.
- Дальше — [03_local_k8s](../03_local_k8s/).
