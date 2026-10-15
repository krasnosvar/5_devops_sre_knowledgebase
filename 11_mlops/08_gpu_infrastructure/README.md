# 08. GPU Infrastructure

## Зачем
Обучение и LLM-инференс упираются в GPU: VRAM определяет, какая модель
вообще влезет, пропускная способность памяти — скорость генерации, а
карты дорогие и их легко недогрузить. Тема объясняет классы GPU и их
характеристики, подключение GPU к Kubernetes (device plugin, GPU
Operator, MIG, time-slicing), облачные инстансы и мониторинг.

## Пререквизиты
- [4_kubernetes/05_scheduling](../../4_kubernetes/05_scheduling/) —
  requests/limits, taints и tolerations: GPU-ноды обычно изолируют
  taint'ом.
- [4_kubernetes/07_manifests_management](../../4_kubernetes/07_manifests_management/)
  — Helm: GPU Operator и DCGM Exporter ставятся чартами.
- [8_observability/02_metrics_prometheus](../../8_observability/02_metrics_prometheus/)
  — метрики DCGM читаются через Prometheus.
- [04_model_serving](../04_model_serving/) — зачем GPU для vLLM.

## Файлы
- [01_theory/gpu_infrastructure.md](./01_theory/gpu_infrastructure.md) —
  классы GPU (consumer, профессиональные, датацентровые), bandwidth,
  квантизация, NVLink vs PCIe, GPU в Kubernetes (NVIDIA, AMD, Intel), GPU
  Operator, MIG и time-slicing, облачные инстансы, мониторинг и
  тюнинг.
- [02_examples/gpu_monitor.sh](./02_examples/gpu_monitor.sh) — сводка по
  GPU на машине: NVIDIA (`nvidia-smi`), AMD (`rocm-smi`), Intel.
- Упражнений нет: без лабы — нужна реальная GPU (локальная карта или
  облачный GPU-инстанс, ☁️ Tier 3), в Docker/kind это не эмулируется.

## Как проходить
1. Прочитать теорию по порядку: железо → Kubernetes → мониторинг.
2. Если на машине есть GPU — запустить `bash gpu_monitor.sh` и сверить
   VRAM с расчётом из раздела про квантизацию для модели, которую
   хотите запустить.

## Когда двигаться дальше
- Можете оценить, сколько VRAM нужно модели N параметров в FP16 и INT4.
- Можете объяснить, почему для инференса LLM важнее bandwidth памяти,
  чем FLOPS.
- Можете описать, что нужно на ноде, чтобы под получил
  `nvidia.com/gpu: 1`, и чем MIG отличается от time-slicing.

Это последняя тема раздела. Далее:
[12_interview_questions_prep](../../12_interview_questions_prep/).
