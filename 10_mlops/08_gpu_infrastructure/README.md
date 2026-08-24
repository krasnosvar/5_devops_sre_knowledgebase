# 10.8 GPU Infrastructure

GPU для ML: от ноутбука с потребительской картой до кластера с H100.
Акцент — на практической эксплуатации GPU в k8s и понимании того, что
отличает разные классы железа.

## Классы GPU

### Потребительские (consumer) — локальная разработка и эксперименты

| Серия | Примеры | Особенности для ML |
|-------|---------|-------------------|
| NVIDIA GeForce | RTX 4090, RTX 4070, RTX 3080 | CUDA, лучшая экосистема; нет ECC, ограниченная пропускная способность PCIe |
| AMD Radeon | RX 7900 XTX, RX 6800 | ROCm (растущая поддержка), PyTorch поддерживает с ROCm 5.x |
| Intel Arc | A770, A750, B580 | oneAPI / SYCL; поддержка в PyTorch через Intel Extension для PyTorch (IPEX); хорошо для инференса открытых моделей |

> Потребительские карты — нормальный выбор для обучения небольших моделей,
> файн-тюнинга с LoRA/QLoRA и локального инференса. Ограничения: VRAM (8–24 GB),
> отсутствие ECC, нет NVLink для multi-GPU.

### Профессиональные / рабочие станции

| Серия | Примеры | Для чего |
|-------|---------|---------|
| NVIDIA RTX (профессиональные) | RTX 6000 Ada, RTX 5000 | ECC, больший VRAM (48–96 GB), поддержка в корпоративном ПО |
| AMD Radeon Pro | W7900X | ECC, OpenCL, ограниченная ML-поддержка |

### Датацентровые — production inference и обучение

| Серия | Примеры | Особенности |
|-------|---------|------------|
| NVIDIA Datacenter | H100, A100, L40S, H200 | NVLink/NVSwitch для multi-GPU, ECC, MIG (Multi-Instance GPU), PCIe и SXM форм-факторы |
| AMD Instinct | MI300X, MI250 | HBM3 память (192 GB в MI300X), ROCm, нет MIG |
| Intel Gaudi | Gaudi 3 | Оптимизирован для трансформеров; oneAPI |
| Google TPU | TPU v5 | Только в GCP; XLA компилятор, не CUDA |

## Ключевые концепции

### Память GPU (VRAM) — главное ограничение

```
Примерные требования к VRAM:
  7B модель, fp16:         ~14 GB  (влезает на RTX 4080 16GB)
  7B модель, int4 (GGUF):  ~4-5 GB (влезает на любую 8GB карту)
  13B модель, fp16:        ~26 GB  (нужен A100 40GB или 2x RTX 4090)
  70B модель, fp16:        ~140 GB (нужен H100 80GB или несколько GPU)
  70B модель, int4:        ~35-40 GB (A100 80GB или 2x RTX 3090)
```

### Пропускная способность памяти (Bandwidth)

Важнее FLOPS для инференса авторегрессионных моделей.
RTX 4090: 1 TB/s. A100: 2 TB/s. H100: 3.35 TB/s.

### Multi-GPU коммуникация

- **NVLink** (NVIDIA): высокоскоростной межкарточный интерфейс (600–900 GB/s);
  только между картами одного сервера; нет на GeForce (кроме ранних моделей)
- **NVSwitch**: коммутатор для масштабирования NVLink на 8+ GPU (DGX)
- **PCIe**: универсальный, медленнее NVLink (~64 GB/s); все карты
- **RDMA / InfiniBand**: между серверами для distributed training

## GPU в Kubernetes

### NVIDIA

```bash
# установка NVIDIA Container Toolkit (на ноде)
# Fedora/RHEL:
dnf install nvidia-container-toolkit
nvidia-ctk runtime configure --runtime=containerd
systemctl restart containerd

# деплой NVIDIA Device Plugin в k8s
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.5/nvidia-device-plugin.yml

# проверить обнаружение GPU
kubectl get nodes -o json | jq '.items[].status.capacity | select(."nvidia.com/gpu")'

# Pod с GPU
# spec:
#   containers:
#     - resources:
#         limits:
#           nvidia.com/gpu: 1
```

### MIG (Multi-Instance GPU) — только A100/H100/A30

Разбивает одну физическую GPU на несколько изолированных экземпляров.

```bash
# включить MIG режим
nvidia-smi -i 0 -mig 1

# создать 3 экземпляра MIG 3g.40gb (для A100 80GB)
nvidia-smi mig -cgi 3g.40gb,3g.40gb -C

# список доступных профилей
nvidia-smi mig -lgip

# в k8s через NVIDIA GPU Operator:
# limits:
#   nvidia.com/mig-3g.40gb: 1
```

### AMD (ROCm)

```bash
# AMD GPU Plugin для k8s
kubectl apply -f https://raw.githubusercontent.com/ROCm/k8s-device-plugin/master/k8s-ds-amdgpu-dp.yaml

# Pod с AMD GPU
# limits:
#   amd.com/gpu: 1
```

### Intel Arc (Intel GPU Plugin)

```bash
# Intel Device Plugins Operator
kubectl apply -k 'https://github.com/intel/intel-device-plugins-for-kubernetes/deployments/gpu_plugin?ref=main'

# Pod с Intel GPU
# limits:
#   gpu.intel.com/i915: 1   # использует i915 драйвер
```

> Intel Arc поддерживается через Intel Extension for PyTorch (IPEX):
> `import intel_extension_for_pytorch as ipex`

### Fractional GPU — разделение одной карты между подами

Когда MIG недоступен (GeForce, Arc, Radeon):

- **NVIDIA Time-Slicing**: делит по времени, не по памяти (нет изоляции памяти)
- **KAI Scheduler** (бывший GPU Sharing Scheduler): продвинутый шедулер для GPU sharing
- **Run:ai**: коммерческий, лучший для enterprise GPU sharing

## Облачные GPU-инстансы

| Провайдер | Инстанс | GPU | Цена |
|-----------|---------|-----|------|
| AWS | p3.2xlarge | V100 16GB | ~$3/ч |
| AWS | p4d.24xlarge | 8x A100 40GB | ~$32/ч |
| AWS | p5.48xlarge | 8x H100 80GB | ~$98/ч |
| GCP | a2-highgpu-1g | A100 40GB | ~$3.7/ч |
| Azure | NC24ads A100 v4 | A100 80GB | ~$3.7/ч |
| Hetzner | GX2-120 | GeForce GTX 1080 Ti | €1.5/ч |
| Lambda Labs | 1x H100 | H100 80GB SXM | ~$2.5/ч (дешевле AWS) |
| RunPod | per-GPU | RTX 4090 | ~$0.74/ч |

> Spot/Preemptible инстансы — 60–90% дешевле, но могут быть прерваны.
> Для обучения: checkpoint каждые N шагов + автоматический restart.

## Мониторинг GPU

```bash
# базовая утилита
nvidia-smi
nvidia-smi dmon -s u  # непрерывный мониторинг utilization
watch -n 1 nvidia-smi

# AMD
rocm-smi
rocm-smi --showuse

# Intel Arc
intel_gpu_top

# Prometheus + Grafana
# NVIDIA: DCGM Exporter (официальный)
helm install dcgm-exporter nvidia/dcgm-exporter -n monitoring

# AMD: amd-gpu-exporter или community экспортер
# Intel: intel-gpu-exporter (node-feature-discovery + intel device plugin)
```

## Связь с другими разделами

- Kubeflow Training Operator → [03_training_pipelines](../03_training_pipelines/)
- vLLM / Triton serving → [04_model_serving](../04_model_serving/)
- k8s RBAC для GPU namespace → [../9_security](../../9_security/)
