# 12. Вычислительная инфраструктура: Гибридные CPU (Intel 155H), iGPU/NPU и GPU в K8s

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка
> по пропускной способности памяти (Memory Bandwidth), привязке к
> P-ядрам Intel 155H, пробросу `/dev/dri` (Intel Arc iGPU) и NVIDIA GPU
> Operator / MIG / DCGM в Kubernetes.

## Зачем

Инженер MLOps обязан понимать физику железа на двух полюсах:
1. **Локальная и Edge-инфраструктура без дискретной NVIDIA GPU** (наш
   стенд **Intel Core Ultra 7 155H + 64 ГБ RAM**): почему скорость
   генерации токенов упирается в пропускную способность памяти (`~80–90
   ГБ/с`), почему `E-ядра` тормозят матричные барьеры `OpenMP`/`ggml` и
   как задействовать встроенную графику **Intel Arc iGPU** (`Vulkan` /
   `OpenVINO`) через `/dev/dri/renderD128`.
2. **Датацентровые GPU-кластеры в Kubernetes** (`NVIDIA A100/H100`,
   `AMD MI300X`): как работают `GPU Operator`, `Device Plugin`, чем
   аппаратная нарезка `MIG` отличается от `Time-Slicing` и какие метрики
   собирает `DCGM Exporter`.

## Пререквизиты

- [Kubernetes](../../4_kubernetes/) (DaemonSet, Resources, Tolerations).
- [06. Деплой и инференс моделей](../06_model_serving/).

## Файлы

- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка по Memory Bandwidth,
  Intel 155H и NVIDIA GPU в K8s.
- `01_theory/`
  - [gpu_infrastructure.md](./01_theory/gpu_infrastructure.md) —
    математика Memory Bandwidth, гибридный процессор Intel 155H (P/E
    ядра, Arc iGPU, OpenVINO, Vulkan), классификация GPU, NVIDIA GPU
    Operator, MIG vs Time-Slicing, DCGM и 10 Q&A.
- `02_examples/`
  - [gpu_monitor.sh](./02_examples/gpu_monitor.sh) — универсальный
    скрипт диагностики GPU/iGPU (`nvidia-smi`, `rocm-smi`, `/dev/dri`
    Intel).

## Как проходить

1. Изучите [теорию](./01_theory/gpu_infrastructure.md).
2. Запустите `./02_examples/gpu_monitor.sh` на своей машине.

## Когда двигаться дальше

Вы готовы к финальному сборному проекту
[13. Capstone: Личная база документов и ИИ-ассистент](../13_capstone_project/),
если:
- можете за 10 секунд оценить скорость генерации токенов (ток/с) любой
  модели по её размеру в ГБ и пропускной способности памяти;
- знаете отличие `MIG` от `Time-Slicing` в Kubernetes.
