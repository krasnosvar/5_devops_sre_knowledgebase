# Деплой и инференс моделей (Model Serving) — шпаргалка

Теория: [model_serving.md](./01_theory/model_serving.md).
`⚠️` = опасная команда / частая ловушка.

## Выбор движка сервинга

| Задача | Рекомендуемый движок (CPU / Intel 155H) | Рекомендуемый движок (NVIDIA GPU) |
| :--- | :--- | :--- |
| **Классический ML / BERT / Эмбеддинги** | **ONNX Runtime** (`CPUExecutionProvider`) + FastAPI | **Triton Inference Server** (ONNX / TensorRT) |
| **LLM (8B..30B MoE)** | **llama.cpp (`llama-server`)** или **Ollama** (`GGUF`) | **vLLM** (`AWQ` / `FP8`, PagedAttention) |
| **Единый шлюз перед моделями** | **LiteLLM Proxy** (OpenAI-совместимый API, роутинг, бюджеты) | **LiteLLM Proxy** |
| **K8s-native CRD** | **KServe** (`InferenceService`) | **KServe** + vLLM / Triton runtime |

## ONNX Runtime на CPU (оптимальные настройки для Intel 155H)

```python
import onnxruntime as ort

opts = ort.SessionOptions()
opts.intra_op_num_threads = 6  # Ровно 6 физических P-ядер Intel 155H
opts.inter_op_num_threads = 1
opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL

session = ort.InferenceSession(
    "/models/doc_router.onnx",
    sess_options=opts,
    providers=["CPUExecutionProvider"],
)
```

## Формула памяти LLM: Веса + KV-cache

$$\text{RAM}_{\text{total}} \approx \text{Weights} + \text{KV\_Cache} + 0.5\text{ GB (buffers)}$$

- **Веса (`Q4_K_M`):** $\approx 0.6 \times N_{\text{params (B)}}$ ГБ
  (для 8B $\approx 5$ ГБ).
- **KV-cache (FP16) на 1 токен:**
  $$2 \times n_{\text{layers}} \times n_{\text{kv\_heads}} \times d_{\text{head}} \times 2\text{ bytes}$$
  Для Llama-3.1-8B (GQA, 8 KV-голов, 32 слоя, $d=128$): **128 КБ/токен**
  ($8192$ токенов контекста $\approx 1$ ГБ ОЗУ на 1 слот).

## Ключевые метрики LLM Serving

| Метрика | Расшифровка | Норма (ориентир) |
| :--- | :--- | :--- |
| **TTFT** | Time To First Token (время префилла промпта до 1-го токена) | `< 1–2 с` для интерактивного чата |
| **TPOT / ITL** | Time Per Output Token / Inter-Token Latency (скорость генерации) | `80–120 мс` (~8–12 ток/с на CPU) |
| **KV-cache usage** | Заполненность буфера контекста (`vllm:gpu_cache_usage_perc`) | `⚠️ > 85%` грозит вытеснением (preemption) |

## Частые ловушки

| Симптом | Причина | Решение |
| :--- | :--- | :--- |
| Pod убивается Kubelet'ом каждые 20 с при старте | `livenessProbe` начинает бить до того, как модель (5 ГБ) загрузилась в ОЗУ | Добавить `startupProbe` с `failureThreshold: 30`, `periodSeconds: 5` |
| Образ весит 12 ГБ, `docker pull` тормозит деплой | Веса модели запечены через `COPY model.bin` в `Dockerfile` | Вынести скачивание весов в `initContainer` на `emptyDir` или общий PVC |
| На CPU `uvicorn --workers 4` роняет ноду в OOM | Каждый процесс Python загружает свою копию модели в RAM ($4 \times 3$ ГБ) | Использовать `--workers 1` на Pod (масштабировать числом реплик Pod'ов) или `mmap` |

> Проверка: структура проверена; не проверено: `vLLM` (требует NVIDIA GPU).
