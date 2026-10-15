# Tier 2 — OrbStack (macOS)

## Зачем

На macOS нет KVM, поэтому стенды из [linux_kvm](../linux_kvm/) напрямую не
работают. OrbStack — лёгкая замена Docker Desktop со встроенными Linux
VM: одной командой получаем Ubuntu-машину для systemd, Ansible по SSH и
kubeadm-экспериментов. Работает на Intel и Apple Silicon.

## Пререквизиты

- macOS и [Homebrew](https://brew.sh/).
- Базовая работа в shell и SSH — [1_linux_and_shell](../../../1_linux_and_shell/).

## Файлы

Только этот README: отдельных `02_examples/`/`03_exercises/` нет — VM
создаются командами `orb`, а упражнения по Linux/Ansible/k8s выполняются
на них из соответствующих разделов базы.

## Как проходить

1. Установить OrbStack и создать одну VM.
2. Проверить SSH-доступ и остановку/запуск VM.
3. Для многоузловых лаб создать несколько VM (раздел ниже).

## Установка

```bash
brew install orbstack
# или: https://orbstack.dev/download
```

## Linux VM через OrbStack

```bash
# создать Ubuntu VM
orb create ubuntu:24.04 lab-node

# список VM
orb list

# подключиться
orb shell lab-node

# или через SSH: OrbStack сам настраивает ~/.ssh/config
ssh lab-node@orb

# остановить / запустить
orb stop lab-node
orb start lab-node

# удалить
orb delete lab-node
```

## Несколько VM для k8s лаб

```bash
orb create ubuntu:24.04 k8s-control
orb create ubuntu:24.04 k8s-worker-1
orb create ubuntu:24.04 k8s-worker-2

# SSH ко всем
orb list  # посмотреть имена
ssh k8s-control@orb
```

CPU и память в OrbStack не выделяются каждой VM отдельно: машины делят
общий лимит, который задаётся в настройках OrbStack.

## Terraform и OrbStack

OrbStack не предоставляет libvirt, поэтому Terraform-стенды из
[linux_kvm/02_examples](../linux_kvm/02_examples/) (провайдер
`dmacvicar/libvirt`) на macOS не запускаются. Варианты:

- создать VM командами `orb create` (выше) и дальше работать с ними
  по SSH/Ansible так же, как с VM из KVM-стенда;
- для Tier-1 упражнений достаточно Docker: OrbStack запускает полноценный
  Docker Engine, `docker compose` работает как обычно;
- если нужен именно Terraform на реальных VM — облачный стенд из
  [04_cloud_vps](../../04_cloud_vps/).

## Особенности Apple Silicon

- OrbStack использует Virtualization.framework (нативный для macOS).
- ARM образы (arm64) — нативно, быстро.
- AMD64 образы — через Rosetta 2, заметно медленнее нативных.
- Для k8s: kind или k3d с arm64-образами.

## Когда двигаться дальше

- Можете создать, остановить и удалить VM и зайти на неё по SSH.
- Понимаете, почему libvirt-стенды не переносятся на macOS и чем их
  заменить.
- Дальше — [03_local_k8s](../../03_local_k8s/).
