# Tier 2 — OrbStack (macOS)

OrbStack — лёгкая замена Docker Desktop с встроенной поддержкой Linux VM.
Работает на Intel и Apple Silicon (M1/M2/M3/M4). Значительно быстрее
и экономнее по памяти чем Docker Desktop + VirtualBox.

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

# или через SSH (OrbStack добавляет запись в /etc/hosts)
ssh lab-node@orb

# остановить / запустить
orb stop lab-node
orb start lab-node

# удалить
orb delete lab-node
```

## Несколько VM для k8s лаб

```bash
orb create ubuntu:24.04 k8s-control --memory 4g --cpu 2
orb create ubuntu:24.04 k8s-worker-1 --memory 2g --cpu 2
orb create ubuntu:24.04 k8s-worker-2 --memory 2g --cpu 2

# SSH ко всем
orb list  # посмотреть имена
ssh k8s-control@orb
```

## Terraform + OrbStack

OrbStack экспортирует libvirt-совместимый сокет:

```hcl
provider "libvirt" {
  uri = "qemu+ssh://admin@lima-orbstack/system"
  # или использовать Docker provider поверх OrbStack Docker Engine
}
```

Для большинства упражнений Tier-2 достаточно Docker Compose внутри OrbStack:
OrbStack запускает полноценный Docker Engine, команды `docker compose` работают
как обычно.

## Особенности Apple Silicon

- OrbStack использует Virtualization.framework (нативный для macOS)
- ARM образы (arm64) — нативно, быстро
- AMD64 образы — через Rosetta 2, медленнее на 10–30%
- Для k8s: используй kind с ARM образами или k3d
