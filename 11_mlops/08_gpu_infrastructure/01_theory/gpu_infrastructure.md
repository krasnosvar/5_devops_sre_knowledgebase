# GPU Infrastructure — теория

## Классификация GPU для ML

### Потребительские (consumer) — локальная разработка

```
NVIDIA GeForce RTX Series:
  RTX 4090:  24GB GDDR6X, 1008 GB/s, TDP 450W — топ для инференса/обучения
  RTX 4080:  16GB GDDR6X, 716 GB/s, TDP 320W
  RTX 4070:  12GB GDDR6X, 504 GB/s, TDP 200W — баланс цена/производительность
  RTX 3090:  24GB GDDR6X, 936 GB/s, TDP 350W — всё ещё хорош

AMD Radeon RX Series:
  RX 7900 XTX: 24GB GDDR6, 960 GB/s — сопоставимо с RTX 4090
  Поддержка: ROCm, HIP (аналог CUDA); PyTorch официально поддерживает

Intel Arc Series:
  Arc A770:  16GB GDDR6, 560 GB/s — oneAPI/SYCL
  Arc B580:  12GB GDDR6 (новинка 2024)
  Поддержка: Intel Extension for PyTorch (IPEX), OpenVINO
```

**Ограничения consumer GPU:**
- Нет ECC (Error Correction Code) — риск тихих ошибок при длинном обучении
- Нет NVLink — нельзя объединить VRAM двух карт
- Нет поддержки в корпоративном ПО (vGPU и т.д.)
- Для домашнего homelab и экспериментов — отлично

### Датацентровые — production и серьёзное обучение

```
NVIDIA Datacenter:
  H100 SXM:   80GB HBM3, 3.35 TB/s bandwidth, NVLink 900 GB/s
  H100 PCIe:  80GB HBM3, 2 TB/s — чуть медленнее, обычный слот PCIe
  A100 SXM:   80GB HBM2e, 2 TB/s — предыдущее поколение
  L40S:       48GB GDDR6, 864 GB/s — инференс-оптимизированная
  H200:       141GB HBM3e — для очень больших моделей

AMD Instinct:
  MI300X:     192GB HBM3 — лидер по VRAM, хорош для огромных LLM
  MI250X:     128GB HBM2e — альтернатива A100

Intel Gaudi 3:
  128GB HBM2e — оптимизирован для трансформеров
  Используется в Intel Developer Cloud
```

## Ключевые характеристики

### Memory Bandwidth — важнее FLOPS для инференса

```python
# Autoregressive generation (LLM) ограничена bandwidth, не вычислениями
# Каждый токен: нужно прочитать веса модели из памяти

# Llama-3 8B, fp16: ~16 GB
# RTX 4090: 1008 GB/s → ~16 GB / 1008 GB/s ≈ 15ms/токен
# H100: 3350 GB/s → ~16 GB / 3350 GB/s ≈ 5ms/токен

# Для батча (несколько параллельных запросов) — амортизируется
```

### Quantization — уменьшить требования к VRAM

```
FP32:  4 байта/параметр    — полная точность (редко нужна)
BF16:  2 байта/параметр    — стандарт для обучения
FP16:  2 байта/параметр    — инференс, потеря точности минимальна
INT8:  1 байт/параметр     — ~20% деградация качества
INT4:  0.5 байта/параметр  — GGUF Q4, хорошо для инференса
NF4:   0.5 байта/параметр  — QLoRA, лучше INT4 для тонкой настройки

# 7B модель, FP16: 7B × 2 = 14 GB
# 7B модель, INT4: 7B × 0.5 = 3.5 GB (+ overhead ~1-2 GB KV cache)
```

### NVLink vs PCIe — коммуникация между GPU

```
PCIe 4.0 x16:  ~64 GB/s (в каждую сторону)
NVLink 3.0:    ~600 GB/s (пара A100)
NVLink 4.0:    ~900 GB/s (пара H100)

Для Tensor Parallelism и large batch:
  NVLink — намного быстрее синхронизация градиентов
  PCIe — достаточно для независимых задач (4x RTX 4090 инференс)
```

## GPU в Kubernetes

```yaml
# NVIDIA Device Plugin — делает GPU видимым для k8s
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nvidia-device-plugin
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: nvidia-device-plugin
  template:
    spec:
      tolerations:
        - key: nvidia.com/gpu
          operator: Exists
          effect: NoSchedule
      containers:
        - name: nvidia-device-plugin
          image: nvcr.io/nvidia/k8s-device-plugin:v0.14.5
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
          volumeMounts:
            - name: device-plugin
              mountPath: /var/lib/kubelet/device-plugins
      volumes:
        - name: device-plugin
          hostPath:
            path: /var/lib/kubelet/device-plugins
```

```yaml
# Pod с GPU запросом
spec:
  containers:
    - name: training
      image: pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime
      resources:
        limits:
          nvidia.com/gpu: 2    # 2 GPU
          cpu: "8"
          memory: 32Gi
      env:
        - name: NVIDIA_VISIBLE_DEVICES
          value: all
        - name: NVIDIA_DRIVER_CAPABILITIES
          value: compute,utility
```

## NVIDIA GPU Operator — автоматизация

```bash
# NVIDIA GPU Operator автоматически:
# - устанавливает NVIDIA drivers на ноду
# - устанавливает Container Toolkit
# - деплоит Device Plugin
# - деплоит DCGM Exporter (метрики в Prometheus)
# - настраивает MIG если нужно

helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm install gpu-operator nvidia/gpu-operator \
  --namespace gpu-operator --create-namespace \
  --set driver.enabled=true \
  --set mig.strategy=mixed      # поддержка MIG (A100/H100)
```

## Мониторинг GPU

```bash
# NVIDIA DCGM Exporter — Prometheus метрики для GPU
helm install dcgm-exporter nvidia/dcgm-exporter \
  --namespace monitoring

# Ключевые метрики (PromQL):
# DCGM_FI_DEV_GPU_UTIL            — утилизация %
# DCGM_FI_DEV_MEM_COPY_UTIL       — memory bandwidth утилизация %
# DCGM_FI_DEV_FB_FREE             — свободная VRAM
# DCGM_FI_DEV_FB_USED             — использованная VRAM
# DCGM_FI_DEV_GPU_TEMP            — температура °C
# DCGM_FI_DEV_POWER_USAGE         — потребление Watts
# DCGM_FI_DEV_ECC_SBE_VOL_TOTAL  — soft-bit errors (ненулевое = проблема)
# DCGM_FI_DEV_NVLINK_BANDWIDTH_TOTAL — NVLink throughput

# Команды
nvidia-smi
nvidia-smi dmon                    # continuous monitoring
nvidia-smi nvlink --status -i 0   # NVLink status
```

## Оптимизация GPU инфраструктуры

```bash
# Persistence Mode — GPU не выключается между запусками (меньше latency старта)
nvidia-smi -pm 1

# Exclusive Process mode — только один процесс на GPU (для критических задач)
nvidia-smi --compute-mode=EXCLUSIVE_PROCESS

# Ограничить Power Limit (снизить TDP для стабильной работы в плотном стеке)
nvidia-smi -pl 300   # 300W вместо 450W (RTX 4090)

# Clock boost (только для overclock-enabled GPU)
nvidia-smi --auto-boost-default=0
nvidia-smi -lgc 1980   # lock graphics clock
```

## Профессиональные GPU (рабочие станции)

Между consumer и датацентровыми картами — профессиональные: NVIDIA RTX
6000 Ada / RTX 5000 Ada, AMD Radeon Pro W7900. Отличия от consumer: ECC,
больше VRAM (до 48 GB), поддержка в корпоративном ПО и сертифицированные
драйверы. Для ML это вариант «одна мощная карта в рабочей станции», когда
24 GB consumer-карты не хватает, а сервер с H100 избыточен.

## Подготовка ноды и GPU других вендоров в Kubernetes

Без GPU Operator ноду готовят вручную: драйвер + NVIDIA Container
Toolkit, затем device plugin.

```bash
# Fedora/RHEL: Container Toolkit (репозиторий NVIDIA уже подключён)
dnf install nvidia-container-toolkit
nvidia-ctk runtime configure --runtime=containerd
systemctl restart containerd

# NVIDIA Device Plugin (манифест из релиза проекта)
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.5/nvidia-device-plugin.yml

# проверить, что нода отдаёт ресурс nvidia.com/gpu
kubectl get nodes -o json | jq '.items[].status.capacity | select(."nvidia.com/gpu")'
```

У других вендоров свой device plugin и своё имя ресурса:

```bash
# AMD (ROCm): ресурс amd.com/gpu
kubectl apply -f https://raw.githubusercontent.com/ROCm/k8s-device-plugin/master/k8s-ds-amdgpu-dp.yaml

# Intel: Intel Device Plugins; ресурс gpu.intel.com/i915 (драйвер i915)
# или gpu.intel.com/xe (новый драйвер xe) — зависит от драйвера на ноде
kubectl apply -k 'https://github.com/intel/intel-device-plugins-for-kubernetes/deployments/gpu_plugin?ref=main'
```

> Ссылки на `master`/`main` удобны для знакомства, но в продакшне
> фиксируйте версию релиза — манифест на ветке может измениться.

## MIG и разделение одной GPU между подами

**MIG (Multi-Instance GPU)** — аппаратное разбиение датацентровой карты
(A100, H100, A30 и новее) на изолированные экземпляры со своей памятью и
вычислительными блоками.

```bash
# включить MIG-режим на GPU 0 (нужен сброс GPU / перезагрузка)
nvidia-smi -i 0 -mig 1

# список доступных профилей
nvidia-smi mig -lgip

# пример для A100 80GB: два экземпляра 3g.40gb
nvidia-smi mig -cgi 3g.40gb,3g.40gb -C

# в k8s (GPU Operator, mig.strategy=mixed) ресурс называется по профилю:
#   limits:
#     nvidia.com/mig-3g.40gb: 1
```

Когда MIG недоступен (consumer-карты, AMD, Intel):
- **NVIDIA time-slicing** (настройка device plugin) — поды делят GPU по
  времени; изоляции памяти нет, один под может занять всю VRAM.
- **KAI Scheduler** — open-source планировщик NVIDIA для GPU-нагрузок в
  k8s с поддержкой дробного выделения GPU.
- **Run:ai** — коммерческая платформа управления GPU-кластером.

## Облачные GPU-инстансы

Типичные варианты (цены меняются и зависят от региона — смотрите
калькулятор провайдера):
- AWS: `p3.2xlarge` (1× V100 16GB), `p4d.24xlarge` (8× A100 40GB),
  `p5.48xlarge` (8× H100 80GB).
- GCP: `a2-highgpu-1g` (1× A100 40GB).
- Azure: `Standard_NC24ads_A100_v4` (1× A100 80GB).
- Специализированные GPU-облака (Lambda, RunPod и т.п.) — обычно дешевле
  крупных облаков за час GPU, но с меньшим набором сопутствующих
  сервисов.

Spot/preemptible-инстансы заметно дешевле, но могут быть прерваны в
любой момент. Для обучения на них обязательны checkpoint каждые N шагов
и автоматический перезапуск с последнего checkpoint.

## Мониторинг GPU других вендоров

```bash
# AMD
rocm-smi
rocm-smi --showuse

# Intel (пакет intel-gpu-tools)
intel_gpu_top
```

Для NVIDIA стандарт — DCGM Exporter (см. «Мониторинг GPU» выше); для
AMD и Intel используются экспортеры от вендоров или сообщества.
Готовый скрипт, который опрашивает все три вендора, —
[../02_examples/gpu_monitor.sh](../02_examples/gpu_monitor.sh).
