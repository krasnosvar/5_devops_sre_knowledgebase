# Bare Metal — фундамент

## Когда bare metal, а не VM или cloud

| Критерий | Bare Metal | VM / Cloud |
|----------|-----------|------------|
| Latency | Минимальная (нет гипервизора) | +0.1–5% overhead |
| GPU/FPGA | Прямой доступ (SR-IOV, PCIe passthrough) | Ограничен (Tesla, A100 в облаке) |
| Стоимость при постоянной нагрузке | Ниже (нет markup провайдера) | Выше (но гибко) |
| Время получения | Недели (заказ, доставка, монтаж) | Минуты |
| Операционная сложность | Высокая | Низкая |
| Compliance / физическая изоляция | Полный контроль | Зависит от провайдера |

**Типичные применения bare metal:**
- HPC (High Performance Computing) — симуляции, рендеринг
- GPU inference в продакшне (LLM, CV) — прямой PCI доступ, лучший throughput
- Финансовый trading — latency-sensitive (<1μs)
- Compliance требования (медицина, финансы, госсектор) — физическая изоляция
- Высоконагруженные СУБД — NVMe прямо к металлу, без виртуализации storage

## Серверное железо — ключевые концепции

### NUMA (Non-Uniform Memory Access)

В современных серверах несколько CPU, каждый со своей банкой памяти.
Доступ к «своей» памяти быстрее чем к «чужой» (через interconnect).

```bash
# посмотреть NUMA топологию
numactl --hardware
numastat

# запустить процесс на конкретном NUMA узле
numactl --cpunodebind=0 --membind=0 ./my_app

# k8s топология-менеджер (Topology Manager)
# --topology-manager-policy=best-effort|restricted|single-numa-node
```

### PCIe — шина подключения GPU/NIC/NVMe

```bash
# список PCIe устройств
lspci -v | grep -A1 "VGA\|3D\|NVIDIA\|AMD"

# пропускная способность PCIe
# Gen3 x16: 16 GB/s (типичный игровой/рабочий ПК)
# Gen4 x16: 32 GB/s (современные серверы)
# Gen5 x16: 64 GB/s (Sapphire Rapids, Genoa)

# SR-IOV — одна физическая карта → несколько виртуальных функций (VF)
# используется для сетевых карт в k8s (DPDK, RDMA)
```

### RDMA (Remote Direct Memory Access)

Позволяет одному серверу читать/писать в память другого, минуя CPU и OS.
Используется для distributed training (gradient sync) и высокопроизводительного хранилища.

```
InfiniBand (до 400 Gb/s): датацентры с GPU кластерами (NVIDIA DGX SuperPOD)
RoCE (RDMA over Converged Ethernet): дешевле, поверх обычного Ethernet
iWARP: менее популярен
```

## Типы серверов

**Tower** — башенный, для небольших офисов/lab. Шумный, неудобен в стойке.

**Rack (1U/2U/4U)** — стоечный. 1U = 4.4 см высоты.
1U: плотность + охлаждение, меньше слотов расширения.
2U/4U: больше дисков, PCIe слотов, GPU.

**Blade** — лезвийный. Высокая плотность, общее питание/охлаждение в chassis.
Сложнее в обслуживании.

**HGX / DGX** — GPU серверы NVIDIA. HGX = 4-8 GPU.
DGX H100: 8x H100, NVSwitch, 640 GB GPU RAM, ~$400k.

## Форм-факторы дисков

```
SFF (2.5"): SATA, SAS, NVMe U.2 — серверные диски
LFF (3.5"): SATA, SAS — объёмные HDD
NVMe U.2 (2.5" SFF): PCIe через U.2 коннектор → очень быстрые (7+ GB/s)
NVMe M.2: компактный, для рабочих станций
EDSFF (E1.S, E3.S): новый форм-фактор для high-density NVMe
```

```bash
# посмотреть диски и их характеристики
lsblk -o NAME,SIZE,TYPE,ROTA,MODEL
# ROTA=0 — SSD, ROTA=1 — HDD

# скорость диска
hdparm -tT /dev/sda         # быстрый тест
fio --name=randread --rw=randread --bs=4k --ioengine=libaio --iodepth=64 \
  --filename=/dev/nvme0n1 --direct=1 --size=1G --runtime=30

# SMART статус (предупреждение о скором отказе)
smartctl -a /dev/sda
```

## Питание и охлаждение

```bash
# энергопотребление сервера
ipmitool dcmi power reading
ipmitool sdr type Temperature   # температуры компонентов
ipmitool sdr type Fan           # обороты вентиляторов

# управление питанием процессора
cpupower frequency-info
cpupower frequency-set -g performance  # режим максимальной производительности
# или: power save для снижения TDP
```
