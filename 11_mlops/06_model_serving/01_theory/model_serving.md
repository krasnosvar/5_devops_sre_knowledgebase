# 06. Деплой и инференс моделей (Model Serving: ONNX, LLM & LiteLLM)

## Содержание
1. [Паттерны подачи моделей: Online, Async, Batch, Streaming](#1-паттерны-подачи-моделей-online-async-batch-streaming)
2. [ONNX Runtime на CPU и доставка весов в Kubernetes](#2-onnx-runtime-на-cpu-и-доставка-весов-в-kubernetes)
3. [Сервинг LLM: llama.cpp / Ollama (CPU) и vLLM (GPU)](#3-сервинг-llm-llamacpp--ollama-cpu-и-vllm-gpu)
4. [Под капотом LLM-инференса: KV-cache, PagedAttention и Batching](#4-под-капотом-llm-инференса-kv-cache-pagedattention-и-batching)
5. [Единый шлюз AI Gateway (LiteLLM Proxy)](#5-единый-шлюз-ai-gateway-litellm-proxy)
6. [Фреймворки сервинга: BentoML, Triton и KServe](#6-фреймворки-сервинга-bentoml-triton-и-kserve)
7. [Стратегии выкатки: Shadow (Dark Launch), Canary и A/B](#7-стратегии-выкатки-shadow-dark-launch-canary-и-ab)
8. [Ключевые метрики инференса в Prometheus](#8-ключевые-метрики-инференса-в-prometheus)
9. [Типовые вопросы на собеседовании (Interview Q&A)](#9-типовые-вопросы-на-собеседовании-interview-qa)

---

## 1. Паттерны подачи моделей: Online, Async, Batch, Streaming

| Паттерн | Латентность | Пропускная способность | Когда использовать |
| :--- | :--- | :--- | :--- |
| **Online (Synchronous REST/gRPC)** | Низкая (`5–100 мс`) | Средняя | Классификация запроса пользователя на лету (роутер интента, антифрод) |
| **Online Streaming (SSE / gRPC)** | Первого токена `< 1 с` | Средняя | Генерация ответа LLM по токенам (чат с документами) |
| **Async / Queue (Kafka / RabbitMQ)** | Средняя (`1–60 с`) | Высокая | Фоновое распознавание (OCR) загруженных PDF/фото и векторизация |
| **Batch (Offline Scoring)** | Высокая (часы) | Очень высокая | Ночной пересчет рекомендаций или скоринга по всей базе |

В нашем сквозном проекте **Личной базы документов**:
- загрузка скана паспорта или медицинского бланка идет через **Async**
  (OCR + чанкинг + эмбеддинги `bge-m3`);
- классификация вопроса пользователя («это вопрос про медицину, налоги
  или оффтоп?») идет через **Online (Synchronous)** на `ONNX Runtime`
  за `~3 мс`;
- ответ по найденным выпискам стримится через **SSE (`Server-Sent
  Events`)** из локальной LLM.

---

## 2. ONNX Runtime на CPU и доставка весов в Kubernetes

### 2.1 Почему не стоит крутить `scikit-learn` или `PyTorch` напрямую в продакшене
1. **Размер образа и холодный старт:** образ с `torch` + `transformers`
   весит 2–4 ГБ. Образ с чистым `onnxruntime` весит ~150 МБ.
2. **Скорость на CPU:** `ONNX Runtime` выполняет слияние операторов
   (`Graph Optimization`: объединяет `MatMul + Add + Gelu` в один вызов
   инструкций `AVX2 / AVX-512 / VNNI`) и при квантовании в `INT8`
   ускоряет линейные слои и трансформеры (`DistilBERT`, `bge-m3`) в
   **2.5–4 раза** на процессоре Intel Core Ultra 7 155H.
3. **Независимость от Python:** один и тот же `.onnx` файл можно
   запустить из Python, Go, Rust или C++.

```python
import onnxruntime as ort
import numpy as np

# Оптимальная конфигурация сессии под 6 P-ядер Intel 155H
sess_options = ort.SessionOptions()
sess_options.intra_op_num_threads = 6
sess_options.inter_op_num_threads = 1
sess_options.graph_optimization_level = (
    ort.GraphOptimizationLevel.ORT_ENABLE_ALL
)

session = ort.InferenceSession(
    "/models/doc_router.onnx",
    sess_options=sess_options,
    providers=["CPUExecutionProvider"],
)
```

### 2.2 Паттерн `initContainer` + `emptyDir` + `startupProbe` в Kubernetes
**Антипаттерн:** запекать веса модели внутрь Docker-образа через
`COPY model.onnx /app/`. Любое переобучение модели потребует пересборки
Docker-образа, а ноды кластера забьют диск старыми слоями.

**Правильный паттерн:** код сервиса лежит в легком Docker-образе, а веса
скачиваются при старте пода через `initContainer` из S3/MLflow в общий
том `emptyDir` (или предзагруженный `PersistentVolumeClaim`):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: doc-router-onnx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: doc-router-onnx
  template:
    metadata:
      labels:
        app: doc-router-onnx
    spec:
      initContainers:
        - name: fetch-model
          image: amazon/aws-cli:2.17.0
          command:
            - sh
            - -c
            - |
              aws --endpoint-url http://minio:9000 \
                s3 cp s3://mlflow/models/doc-router/champion/model.onnx \
                /models/doc_router.onnx
          volumeMounts:
            - name: model-volume
              mountPath: /models
      containers:
        - name: inference
          image: registry.local/mlops/doc-router:v1.0
          ports:
            - containerPort: 8000
          resources:
            requests:
              cpu: "2"
              memory: "512Mi"
            limits:
              cpu: "6"
              memory: "1Gi"
          # КРИТИЧНО: даем поду время загрузить веса в RAM до старта livenessProbe
          startupProbe:
            httpGet:
              path: /health/ready
              port: 8000
            periodSeconds: 5
            failureThreshold: 24  # до 120 секунд на инициализацию модели
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 8000
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /health/live
              port: 8000
            periodSeconds: 10
          volumeMounts:
            - name: model-volume
              mountPath: /models
              readOnly: true
      volumes:
        - name: model-volume
          emptyDir: {}
```

---

## 3. Сервинг LLM: llama.cpp / Ollama (CPU) и vLLM (GPU)

### 3.1 Локальный и CPU/iGPU сервинг (`llama.cpp` и `Ollama`)
На машинах без NVIDIA GPU (как наш стенд **Intel Core Ultra 7 155H +
64 ГБ ОЗУ**) стандарт де-факто — `llama.cpp` (`llama-server`) и
обертка над ним `Ollama`. Оба отдают **OpenAI-совместимый API**
(`/v1/chat/completions`, `/v1/embeddings`):

```bash
# Запуск llama-server напрямую с привязкой к 6 физическим P-ядрам,
# ограничением контекста и параллельными слотами (continuous batching):
taskset -c 0-11 llama-server \
  -m /models/qwen2.5-7b-instruct-q4_k_m.gguf \
  --threads 6 \
  --ctx-size 8192 \
  --parallel 2 \
  --cont-batching \
  --metrics \
  --host 0.0.0.0 --port 8080
```

### 3.2 Продакшен GPU-сервинг (`vLLM`)
На серверах с NVIDIA GPU для высоконагруженного сервинга используется
**vLLM**:

```bash
docker run --runtime nvidia --gpus all \
  -p 8000:8000 \
  -e HF_TOKEN="$HF_TOKEN" \
  vllm/vllm-openai:latest \
  --model Qwen/Qwen2.5-7B-Instruct \
  --tensor-parallel-size 1 \
  --max-model-len 8192 \
  --gpu-memory-utilization 0.85 \
  --max-num-seqs 256
```

Ключевые флаги масштабирования `vLLM`:
- `--tensor-parallel-size N` — разрезает матрицы каждого слоя между $N$
  видеокартами внутри одного узла (требует быстрой связи NVLink/PCIe);
- `--pipeline-parallel-size M` — распределяет слои модели последовательно
  по разным GPU/узлам;
- `--quantization awq` (или `gptq`, `fp8`) — запуск квантованной модели
  для экономии VRAM и ускорения чтения весов.

---

## 4. Под капотом LLM-инференса: KV-cache, PagedAttention и Batching

### 4.1 Две фазы генерации LLM: Prefill vs Decode
1. **Prefill (обработка входного промпта):** все входные токены промпта
   известны сразу и перемножаются параллельно за один проход. Эта фаза
   **Compute-bound** (упирается в FLOPS процессора/GPU) и определяет
   метрику **TTFT (Time To First Token)**.
2. **Decode (авторегрессионная генерация по одному токену):** чтобы
   сгенерировать каждый следующий токен, нужно прочитать из памяти **все
   веса модели** ради вектора размера `batch_size = 1`. Эта фаза
   **Memory-bandwidth-bound** (упирается в ПСП ОЗУ/VRAM) и определяет
   метрику **TPOT / ITL (Time Per Output Token)**.

### 4.2 Что такое KV-cache и сколько памяти он занимает
Чтобы на шаге генерации токена №500 не пересчитывать векторы ключей ($K$)
и значений ($V$) для предыдущих 499 токенов, их кэшируют в оперативной/
видеопамяти (**KV-cache**).

Формула размера KV-cache (в `FP16`, т.е. 2 байта на число) на **1 токен**:
$$\text{KV}_{\text{per\_token}} = 2_{\text{(K и V)}} \times n_{\text{layers}} \times n_{\text{kv\_heads}} \times d_{\text{head}} \times 2\text{ bytes}$$

Пример для модели `Llama-3.1-8B` / `Qwen2.5-7B` с **GQA (Grouped-Query
Attention)**:
- $n_{\text{layers}} = 32$, $n_{\text{kv\_heads}} = 8$, $d_{\text{head}} = 128$:
- На 1 токен: $2 \times 32 \times 8 \times 128 \times 2 = 131\,072\text{ байт} = \mathbf{128\text{ КБ}}$.
- На контекст `8192` токена для **одного** запроса: $8192 \times 128\text{ КБ} = \mathbf{1\text{ ГБ}}$.
- Если сервер обрабатывает **16 параллельных запросов** с контекстом
  8192, только под KV-cache потребуется **16 ГБ памяти** (больше, чем
  сами веса модели!).

### 4.3 PagedAttention и Continuous Batching
- **Проблема наивного выделения памяти:** раньше под каждый запрос
  заранее бронировался непрерывный кусок памяти под максимальный
  `max_model_len` (например, 8192 токена), даже если запрос состоял из
  100 токенов. До 60–80% памяти терялось из-за внутренней и внешней
  фрагментации.
- **PagedAttention (в vLLM и современном llama.cpp):** по аналогии с
  виртуальной памятью ОС Linux делит KV-cache на небольшие блоки
  фиксированного размера (например, по 16 токенов) и выделяет их по мере
  роста ответа по таблице блоков. Фрагментация падает до `< 4%`, а общий
  системный промпт можно разделять между запросами (**Prefix Caching**).
- **Static Batching vs Continuous (In-flight) Batching:** при статическом
  батчинге, если в батче из 4 запросов три ответили по 20 токенов, а
  четвертый генерирует 500 токенов, первые три ждут окончания четвертого.
  При **Continuous Batching** на место завершившегося запроса на
  следующей же итерации генерации (token step) подставляется новый запрос
  из очереди.

---

## 5. Единый шлюз AI Gateway (LiteLLM Proxy)

В реальной архитектуре приложение **никогда не должно** ходить напрямую
в `http://ollama:11434` или жестко привязываться к SDK конкретного
облачного провайдера. Перед всеми моделями ставится **AI Gateway**
(стандарт в open-source — **LiteLLM Proxy**):

```yaml
# litellm_config.yaml
model_list:
  - model_name: doc-assistant-fast
    litellm_params:
      model: ollama/qwen2.5:1.5b
      api_base: http://ollama:11434
  - model_name: doc-assistant-smart
    litellm_params:
      model: ollama/qwen2.5:7b-instruct-q4_K_M
      api_base: http://ollama:11434
router_settings:
  fallbacks: [{"doc-assistant-smart": ["doc-assistant-fast"]}]
  num_retries: 2
  timeout: 30
```

Что дает `LiteLLM Proxy` инженеру:
1. **Единый контракт `/v1/chat/completions`** для десятков бэкендов
   (`Ollama`, `vLLM`, `OpenAI`, `Anthropic`, `Bedrock`).
2. **Fallback & Load Balancing:** если тяжелая модель перегружена или
   вернула 503/таймаут, запрос прозрачно уходит на быструю модель.
3. **Rate Limiting и учет токенов** по виртуальным API-ключам команд.
4. **Интеграция с Observability:** автоматическая отправка трейсов и
   стоимости токенов в `Langfuse` / `Prometheus`.

---

## 6. Фреймворки сервинга: BentoML, Triton и KServe

### 6.1 BentoML (Python-first упаковка микросервисов)
Удобен для классических моделей и кастомных пайплайнов:

```python
import bentoml
import numpy as np


@bentoml.service(resources={"cpu": "2"}, traffic={"timeout": 10})
class DocRouterService:
    def __init__(self) -> None:
        # Загружается один раз при старте воркера
        self.model = bentoml.sklearn.load_model("doc_router:latest")

    @bentoml.api
    def predict(self, features: np.ndarray) -> dict:
        proba = self.model.predict_proba(features)[0]
        return {
            "category_id": int(proba.argmax()),
            "confidence": float(proba.max()),
        }
```

### 6.2 NVIDIA Triton Inference Server (C++ multi-framework сервер)
Поддерживает `ONNX`, `TensorRT`, `PyTorch`, `OpenVINO`, `FIL (XGBoost)`
и умеет собирать одиночные HTTP/gRPC-запросы в динамические батчи на
нативном уровне:

```protobuf
# config.pbtxt
name: "doc_router"
platform: "onnxruntime_onnx"
max_batch_size: 64
dynamic_batching {
  preferred_batch_size: [16, 32, 64]
  max_queue_delay_microseconds: 2000
}
```

### 6.3 KServe (Kubernetes CRD `InferenceService`)
Декларативный стандарт деплоя моделей в Kubernetes со встроенной
поддержкой `storageUri` (автоматически создает `storage-initializer`
initContainer), разделением на `predictor` / `transformer` / `explainer`
и канареечным роутингом трафика.

---

## 7. Стратегии выкатки: Shadow (Dark Launch), Canary и A/B

| Стратегия | Кто видит ответ новой модели `v2`? | Какую задачу решает? |
| :--- | :--- | :--- |
| **Shadow (Dark Launch / Зеркалирование)** | **Никто** (ответ `v2` логируется асинхронно и отбрасывается; пользователю отвечает `v1`) | Проверка технической стабильности (латентность, OOM, отсутствие 500-х ошибок) и дрифта предсказаний на 100% реального трафика без риска для бизнеса |
| **Canary (Канарейка)** | Реальные пользователи (сначала 1–5% трафика, затем 25% → 100%) | Плавная выкатка с автоматическим откатом (Argo Rollouts / Istio) при деградации SLI |
| **A/B Testing** | Реальные пользователи (например, 50% на `v1`, 50% на `v2` с привязкой по `user_id`) | Статистическая проверка **бизнес-гипотезы** (увеличила ли модель `v2` конверсию или долю решенных запросов) |

---

## 8. Ключевые метрики инференса в Prometheus

```promql
# 1. Пропускная способность (RPS предсказаний по категориям документов)
sum by (predicted_class) (rate(doc_router_predictions_total[5m]))

# 2. Латентность классического инференса (p95)
histogram_quantile(0.95, sum by (le) (rate(inference_duration_seconds_bucket[5m])))

# 3. LLM: Time To First Token (p95 TTFT)
histogram_quantile(0.95, sum by (le) (rate(vllm:time_to_first_token_seconds_bucket[5m])))

# 4. LLM: Заполненность KV-cache (> 0.85 — сигнал к масштабированию)
vllm:gpu_cache_usage_perc
```

---

## 9. Типовые вопросы на собеседовании (Interview Q&A)

**1. Почему упаковка весов модели (5 ГБ) внутрь Docker-образа через
`COPY` считается антипаттерном, и как правильно доставлять веса в Pod?**
*Ответ:* При вшивании весов в образ любое обновление модели (даже без
изменения единой строчки кода сервиса) требует пересборки и прокачки
многогигабайтного слоя через CI и Container Registry, замедляет
масштабирование подов (`ImagePull`) и быстро забивает диск узлов K8s
при ротации версий. Правильные подходы:
1. Скачивать веса при старте пода в `initContainer` из S3/MLflow в
   общий том `emptyDir` (как делает `storage-initializer` в KServe).
2. Монтировать ReadOnlyMany PVC с общим кэшем моделей.
3. Использовать современные механизмы ленивого монтирования OCI-артефактов.

**2. Что произойдет с Kubernetes Pod'ом, если модель загружается в
память при старте 50 секунд, а настроены только стандартные
`livenessProbe` и `readinessProbe` (`initialDelaySeconds: 10,
periodSeconds: 10, failureThreshold: 3`)?**
*Ответ:* Через $10 + 3 \times 10 = 40$ секунд после старта контейнера
`livenessProbe` зафиксирует 3 неудачи подряд, Kubelet решит, что процесс
завис, и убьет контейнер (`SIGKILL`). Контейнер начнет грузить модель
заново и попадет в бесконечный цикл **`CrashLoopBackOff`**. Чтобы этого
не происходило, обязательно настраивают **`startupProbe`**, который
блокирует запуск `livenessProbe` до тех пор, пока приложение один раз не
ответит `200 OK` о готовности весов.

**3. Почему запуск FastAPI-сервиса с PyTorch/ONNX-моделью в 3 ГБ через
`gunicorn/uvicorn --workers 4` внутри одного контейнера с лимитом 8 ГБ
RAM приводит к `OOMKilled`?**
*Ответ:* Флаг `--workers 4` создает 4 отдельных процесса ОС Linux. Если
каждый воркер в своем `@app.on_event("startup")` или `lifespan` читает
файл модели в оперативную память (без `mmap`), потребление памяти
учетверяется: $4 \times 3\text{ ГБ} = 12\text{ ГБ} > 8\text{ ГБ}$, и
ядро Linux убивает контейнер по `cgroup OOM`. В Kubernetes для
ML-сервисов ставят **1 воркер на контейнер** (`--workers 1`) и
масштабируют горизонтально числом реплик Pod'ов через HPA, либо
используют `mmap` / специализированный сервер (Triton).

**4. Зачем в Python-сервисе с `ONNX Runtime` вызывать инференс в
асинхронном FastAPI через `run_in_executor` (или обычную `def`, а не
`async def`)?**
*Ответ:* Если объявить эндпоинт как `async def predict()` и внутри него
напрямую вызвать синхронный CPU-bound метод `session.run()`, этот вызов
заблокирует единственный `event loop` (`asyncio`) на все время счета, и
сервис перестанет отвечать даже на легкие запросы `/health/live` (что
может спровоцировать рестарт пода по `livenessProbe`). Если объявить
эндпоинт как обычный `def predict()` или использовать
`await loop.run_in_executor(...)`, FastAPI выполнит вызов `session.run()`
в отдельном потоке пула, а поскольку Си-ядро `ONNX Runtime` отпускает
Python GIL во время матричных вычислений, `event loop` останется
отзывчивым.

**5. В чем фундаментальное отличие фазы `Prefill` от фазы `Decode` при
инференсе LLM с точки зрения загрузки железа?**
*Ответ:*
- На фазе **`Prefill`** все токены входного промпта обрабатываются
  параллельно (матрица-на-матрицу, `GEMM`). Вычислительная интенсивность
  высокая, и система упирается в вычислительную мощность ядер
  (**Compute-bound**).
- На фазе **`Decode`** токены генерируются строго по одному: для каждого
  нового токена нужно прочитать из памяти все гигабайты весов модели
  ради умножения матрицы на вектор (`GEMV`). Система простаивает в
  ожидании чтения из памяти (**Memory-bandwidth-bound**).

**6. Что такое `KV-cache` в трансформерах, почему он растет линейно с
длиной контекста и как его уменьшает архитектура `GQA` (Grouped-Query
Attention)?**
*Ответ:* При авторегрессионной генерации токен на позиции $t$ должен
обратить внимание (`Attention`) на все предыдущие токены $1 \dots t-1$.
Чтобы не пересчитывать их проекции ключей ($K$) и значений ($V$) заново
на каждом шаге, их сохраняют в буфер `KV-cache`. Его объем растет
пропорционально `batch_size * seq_len`. В классическом `MHA (Multi-Head
Attention)` у каждой из 32 голов внимания свои собственные матрицы $K$ и
$V$. В `GQA` группы из 4–8 голов запроса ($Q$) разделяют одну общую пару
$K$ и $V$ (например, всего 8 или 4 KV-головы вместо 32), что уменьшает
размер `KV-cache` в **4–8 раз** почти без потери качества.

**7. Какую проблему решает `PagedAttention` в `vLLM` и `llama.cpp`?**
*Ответ:* До `PagedAttention` фреймворки выделяли под `KV-cache` каждого
запроса единый непрерывный кусок памяти максимальной длины (`max_seq_len`),
поскольку заранее неизвестно, сколько токенов сгенерирует модель. Это
приводило к потере 60–80% памяти из-за внутренней и внешней фрагментации
и резко ограничивало число одновременных запросов (`batch size`).
`PagedAttention` разбивает `KV-cache` на маленькие несмежные страницы
фиксированного размера (по аналогии со страничной виртуальной памятью
ОС), выделяя их динамически по мере генерации.

**8. Чем `Continuous (In-flight) Batching` отличается от `Dynamic
Batching` в классическом Triton?**
*Ответ:* В классическом `Dynamic Batching` сервер копит запросы в
очереди 1–2 миллисекунды, склеивает их в один тензор и выполняет ровно
один прямой проход (`forward pass`), после чего все запросы батча
завершаются одновременно. В LLM генерация ответа состоит из сотен
итераций, и разные запросы в одном батче требуют разного числа выходных
токенов (один — 15 токенов, другой — 800). `Continuous Batching`
работает на уровне **одной итерации генерации токена**: как только один
запрос в батче сгенерировал токен конца строки (`<eos>`), он тут же
покидает батч, а на его место на следующей же итерации вставляется новый
запрос без ожидания остальных.

**9. Чем отличается `Shadow Deployment (Dark Launch)` от `Canary` и
`A/B-тестирования`?**
*Ответ:*
- При **Shadow Deployment** входящий продакшен-трафик дублируется
  (зеркалируется, например через `Istio Mirroring`) на новую модель
  `v2`, но её ответы **не возвращаются пользователю**, а только
  логируются для проверки латентности, нагрузки на CPU/RAM и сравнения
  предсказаний с `v1`.
- При **Canary** реальные пользователи на малой доле трафика (1–5%)
  получают ответы от `v2` для проверки технической стабильности перед
  раскаткой на 100%.
- При **A/B-тестировании** трафик делится между `v1` и `v2` (обычно со
  стабильным хэшированием по `user_id`) на длительный срок, чтобы с
  помощью статистических критериев измерить влияние модели на
  **бизнес-метрики** (конверсию, удержание, выручку).

**10. Зачем ставить `LiteLLM Proxy` перед локальными (`Ollama`/`vLLM`) и
внешними LLM-провайдерами вместо прямых вызовов из кода приложения?**
*Ответ:* Прямые вызовы из микросервисов размазывают логику ретраев,
таймаутов, ротации ключей и имен моделей по десятку репозиториев.
`LiteLLM Proxy` выступает как единая точка управления (AI Gateway):
предоставляет единый OpenAI-совместимый API, автоматически переключает
трафик на резервную модель (`fallback`) при падении основной, считает
расход токенов и бюджет по командам и централизованно отправляет трейсы
в систему наблюдаемости (`Langfuse` / `OpenTelemetry`).
