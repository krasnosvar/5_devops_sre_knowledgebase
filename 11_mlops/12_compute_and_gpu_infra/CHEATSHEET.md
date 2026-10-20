# Вычислительная инфраструктура: CPU, iGPU/NPU и GPU — шпаргалка

Теория: [gpu_infrastructure.md](./01_theory/gpu_infrastructure.md).
`⚠️` = опасная команда / частая ловушка.

## Формула скорости генерации LLM (Memory Bandwidth Bound)

$$\text{Tokens/sec (max)} \approx \frac{\text{Memory Bandwidth (GB/s)}}{\text{Active Model Weights (GB)}} \times \eta \quad (\eta \approx 0.6\text{..}0.75)$$

| Устройство | Память | ПСП (Bandwidth) | `Qwen2.5-7B Q4_K_M` (~4.7 ГБ) | `Qwen3-30B-A3B Q4` (MoE, активны ~2 ГБ из 18 ГБ) |
| :--- | :--- | :--- | :--- | :--- |
| **Intel Core Ultra 7 155H** | 64 ГБ DDR5 / LPDDR5x | `~85–110 ГБ/с` | `~10–14 ток/с` | `~22–30 ток/с` (хит для 64 ГБ ОЗУ!) |
| **NVIDIA RTX 4090** | 24 ГБ GDDR6X | `1008 ГБ/с` | `~130 ток/с` | `~250+ ток/с` |
| **NVIDIA H100 SXM** | 80 ГБ HBM3 | `3350 ГБ/с` | `~350+ ток/с` | `~600+ ток/с` |

## Настройки Intel Core Ultra 7 155H (CPU + Arc iGPU) для инференса

| Контур | Команда / Настройка | Зачем |
| :--- | :--- | :--- |
| **P-ядра CPU (`0..11`)** | `taskset -c 0-11` + `--threads 6` (`OMP_NUM_THREADS=6`) | `⚠️` Исключить медленные E/LP-E ядра (`12..21`) из барьеров `ggml` / `OpenMP` |
| **Intel Arc iGPU в Docker** | `devices: ["/dev/dri:/dev/dri"]` + `llama.cpp` Vulkan / SYCL | Разгрузка матричного умножения (`Prefill`) на встроенный графический ускоритель |
| **OpenVINO Runtime** | `optimum-cli export openvino --weight-format int8` | Ускорение BERT/BGE-M3/Whisper на CPU (`VNNI`) и Intel iGPU/NPU |

## Разделение одной NVIDIA GPU между Pod'ами в Kubernetes

| Технология | Аппаратная изоляция памяти и ядер? | Какие карты поддерживают | Что будет при OOM в соседнем поде? |
| :--- | :--- | :--- | :--- |
| **MIG (Multi-Instance GPU)** | **Да** (до 7 физически изолированных инстансов) | Только датацентровые (`A30`, `A100`, `H100`, `H200`) | Соседние поды **не страдают** |
| **Time-Slicing** | **Нет** (общая VRAM, переключение контекста по времени) | Любые NVIDIA GPU (включая RTX) | `⚠️` Падение или OOM в одном поде может уронить соседей |

> Проверка: `./02_examples/gpu_monitor.sh` проверен через `bash -n`.
