# Model Serving

## Паттерны подачи модели

| Паттерн | Latency | Throughput | Когда использовать |
|---------|---------|------------|-------------------|
| **Online (synchronous)** | Low | Medium | REST API, real-time predictions |
| **Async / queue** | Medium | High | Non-blocking, background scoring |
| **Batch** | High | Very High | Overnight scoring, retraining |
| **Streaming** | Low | High | Kafka consumers, real-time features |

## vLLM — для LLM inference

```bash
# Запуск (GPU)
docker run --runtime nvidia --gpus all \
  -p 8000:8000 \
  vllm/vllm-openai:latest \
  --model meta-llama/Llama-3.1-8B-Instruct \
  --tensor-parallel-size 1 \          # 1 GPU
  --max-model-len 8192 \
  --gpu-memory-utilization 0.85 \
  --max-num-seqs 256 \                # максимум параллельных запросов
  --quantization awq                  # AWQ quantization для экономии VRAM

# Проверить
curl http://localhost:8000/v1/models
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Llama-3.1-8B-Instruct",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 100,
    "temperature": 0.7
  }'

# Метрики (Prometheus)
curl http://localhost:8000/metrics | grep vllm
# vllm:num_requests_running — активных запросов
# vllm:gpu_cache_usage_perc — использование KV cache
# vllm:generation_tokens_total — токенов сгенерировано
```

**Ключевые настройки производительности:**

```bash
# Tensor Parallelism — разделить модель между GPU
--tensor-parallel-size 2   # 2 GPU, модель разделена по layers

# Pipeline Parallelism — разделить pipeline между GPU
--pipeline-parallel-size 2  # 2 GPU, разные stages

# Quantization — уменьшить VRAM
--quantization awq          # AWQ: quality ~ FP16, VRAM вдвое меньше
--quantization gptq         # GPTQ: чуть хуже AWQ
--dtype bfloat16            # по умолчанию для современных GPU
```

## BentoML — для классических ML и custom serving

```python
# service.py
import bentoml
import numpy as np
from bentoml.io import NumpyNdarray, JSON

# сохранить модель в BentoML store
bentoml.sklearn.save_model("fraud_detector", model,
                           signatures={"predict": {"batchable": True}},
                           metadata={"accuracy": 0.97, "version": "v3.1"})

# определить сервис
svc = bentoml.Service("fraud_detector_svc",
                      runners=[bentoml.sklearn.get("fraud_detector:latest").to_runner()])

@svc.api(input=JSON(), output=JSON())
async def predict(input_data: dict) -> dict:
    features = np.array(input_data["features"])
    predictions = await svc.runners["fraud_detector_svc"].predict.async_run(features)
    return {
        "prediction": int(predictions[0]),
        "probability": float(predictions[1][0])
    }
```

```bash
# тестовый запуск
bentoml serve service:svc --reload

# собрать bento (образ для деплоя)
bentoml build
bentoml containerize fraud_detector_svc:latest

# деплой в k8s
helm install fraud-detector bentoml/yatai \
  --set bentoDeployment.bento=fraud_detector_svc:abc123
```

## KServe (KFServing) — serving в k8s

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: fraud-detector
  namespace: production
spec:
  predictor:
    sklearn:
      storageUri: s3://my-bucket/models/fraud-detector/v3.1/
      resources:
        requests:
          cpu: "1"
          memory: 2Gi
        limits:
          cpu: "2"
          memory: 4Gi
      minReplicas: 2
      maxReplicas: 10

  # Transformer — предобработка/постобработка
  transformer:
    containers:
      - name: transformer
        image: my-registry/fraud-transformer:v1.0
        env:
          - name: PREDICTOR_HOST
            value: "fraud-detector-predictor-default"

  # Explainer — объяснение предсказаний (SHAP)
  explainer:
    alibi:
      type: AnchorTabular
      storageUri: s3://my-bucket/explainers/fraud-detector/
```

## Triton Inference Server — для multi-framework

NVIDIA Triton — serving сервер поддерживающий TensorFlow, PyTorch, ONNX,
TensorRT, Python, FIL (XGBoost/LightGBM). Высокая производительность, batching.

```
model_repository/
├── fraud_detector/
│   ├── config.pbtxt
│   └── 1/
│       └── model.onnx
└── text_classifier/
    ├── config.pbtxt
    └── 1/
        └── model.pt
```

```protobuf
# config.pbtxt
name: "fraud_detector"
platform: "onnxruntime_onnx"
max_batch_size: 64
dynamic_batching {
  preferred_batch_size: [16, 32, 64]
  max_queue_delay_microseconds: 100
}
input [{
  name: "input"
  data_type: TYPE_FP32
  dims: [-1, 128]   # -1 = batch dimension
}]
output [{
  name: "output"
  data_type: TYPE_FP32
  dims: [-1, 2]
}]
```

## A/B тестирование моделей

```yaml
# Istio VirtualService: 90% трафика на v1, 10% на v2
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: fraud-detector
spec:
  http:
    - route:
        - destination:
            host: fraud-detector-v1
            port:
              number: 80
          weight: 90
        - destination:
            host: fraud-detector-v2
            port:
              number: 80
          weight: 10
```

```python
# Логировать какая версия дала предсказание (для анализа)
response = {
    "prediction": result,
    "model_version": os.environ["MODEL_VERSION"],
    "experiment_id": "ab-test-2024-01"
}
```

## Ключевые метрики serving

```promql
# Throughput (предсказаний/сек)
rate(predictions_total[5m])

# Latency (p95)
histogram_quantile(0.95, rate(prediction_duration_seconds_bucket[5m]))

# Error rate
rate(predictions_total{status="error"}[5m]) / rate(predictions_total[5m])

# Queue depth (для async serving)
serving_queue_size

# GPU utilization (для LLM)
# vllm:gpu_cache_usage_perc > 0.9 → нужно больше GPU или уменьшить max_model_len
```
