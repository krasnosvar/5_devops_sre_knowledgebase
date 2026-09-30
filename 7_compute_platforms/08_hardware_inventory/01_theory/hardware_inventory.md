# Hardware Inventory

## Инвентаризация сервера

```bash
# Полная информация о системе
dmidecode -t system          # производитель, модель, S/N, UUID
dmidecode -t bios            # версия BIOS/UEFI, дата
dmidecode -t processor       # CPU: модель, сокеты, ядра, потоки
dmidecode -t memory          # RAM: размер, тип, скорость, слоты

# Краткая сводка
lshw -short                  # иерархический список всего железа
lshw -class processor        # только CPU
lshw -class memory           # только память
lshw -class disk             # только диски
lshw -class network          # только сетевые карты
lshw -json | jq .            # в JSON для автоматизации

# CPU подробно
lscpu                        # архитектура, ядра, NUMA, кэши
cat /proc/cpuinfo            # детальная информация по каждому core
```

## Диски и NVMe

```bash
# Список всех блочных устройств
lsblk -o NAME,SIZE,TYPE,ROTA,MODEL,SERIAL,MOUNTPOINT
# ROTA=0 → SSD, ROTA=1 → HDD

# NVMe устройства
nvme list
nvme id-ctrl /dev/nvme0      # модель, S/N, firmware
nvme smart-log /dev/nvme0    # SMART данные NVMe
nvme error-log /dev/nvme0    # лог ошибок

# SATA/SAS SMART
smartctl -a /dev/sda         # полная информация + SMART атрибуты
smartctl -H /dev/sda         # только статус здоровья
smartctl -t short /dev/sda   # запустить короткий self-test

# Критичные SMART атрибуты:
# Reallocated_Sector_Ct > 0 → были плохие секторы (следить)
# Current_Pending_Sector > 0 → потенциально плохие (срочно)
# Offline_Uncorrectable > 0 → некорректируемые ошибки (менять диск)
# Power_On_Hours → наработка в часах
```

## Сетевые карты

```bash
# Список сетевых интерфейсов
ip link show
lshw -class network

# Скорость и параметры NIC
ethtool eth0                 # скорость, дуплекс, auto-negotiation
ethtool -i eth0              # драйвер, версия firmware
ethtool -S eth0              # статистика (TX/RX errors, drops)

# PCI устройства
lspci | grep -i "ethernet\|network\|infiniband\|mellanox\|intel\|broadcom"
lspci -v -s 00:1f.6          # подробно о конкретном устройстве

# Firmware сетевой карты
ethtool --show-features eth0 | grep "tx-checksumming"
```

## PCIe и GPU

```bash
# Все PCIe устройства
lspci -v

# GPU
lspci | grep -i "vga\|3d\|display\|nvidia\|amd\|intel arc"
lspci -v -s 01:00.0          # подробно о GPU

# NVIDIA
nvidia-smi                   # статус GPU (temp, power, utilization, memory)
nvidia-smi -q                # полная информация
nvidia-smi topo -m           # топология (NVLink между GPU)
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv

# AMD
rocm-smi                     # статус AMD GPU
rocm-smi --showproductname
rocm-smi --showmeminfo vram

# Intel Arc
intel_gpu_top                # TUI для Intel GPU
```

## Firmware обновления

```bash
# fwupd — универсальный инструмент (поддерживает Dell, HP, Lenovo, Intel, etc.)
fwupdmgr get-devices         # устройства поддерживающие fwupd
fwupdmgr refresh             # обновить базу прошивок
fwupdmgr get-updates         # доступные обновления
fwupdmgr update              # обновить всё

# Dell (через RACADM или iDRAC)
racadm fwupdate -g -u -a /tmp/firmware.exe   # через iDRAC

# HP (через hponcfg или iLO)
hponcfg -f ilo_firmware.xml
```

## Мониторинг железа в Prometheus

```bash
# node_exporter собирает:
# - node_hwmon_temp_celsius — температуры (hwmon/lm-sensors)
# - node_disk_io_time_seconds_total — I/O время диска
# - node_network_receive_errs_total — ошибки сети
# - node_memory_HardwareCorrupted_bytes — аппаратные ошибки памяти

# lm-sensors — температуры и напряжения
sensors                      # текущие показания
sensors-detect               # обнаружить сенсоры (запустить один раз)

# smartd — daemon для мониторинга SMART
systemctl enable --now smartd
# настройка в /etc/smartd.conf:
# /dev/sda -a -o on -S on -s (S/../.././02|L/../../6/03) -m admin@example.com -M exec /usr/share/smartmontools/smartd-runner
```

## Автоматизированная инвентаризация

```bash
# Netbox — open-source DCIM (Data Center Infrastructure Management)
# Можно автоматически заполнять через API

#!/usr/bin/env python3
import json, subprocess, requests

# собрать данные о сервере
dmidecode = json.loads(subprocess.check_output(["dmidecode", "--type=system", "-q"]))
lshw = json.loads(subprocess.check_output(["lshw", "-json"]))

# отправить в Netbox API
response = requests.post(
    "http://netbox.example.com/api/dcim/devices/",
    headers={"Authorization": "Token abc123"},
    json={
        "name": dmidecode.get("System Information", {}).get("Product Name"),
        "serial": dmidecode.get("System Information", {}).get("Serial Number"),
    }
)
```
