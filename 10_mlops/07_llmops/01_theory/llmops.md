# LLMOps — LLM в продакшне

## Чем LLM отличается от обычной ML модели

| | Классическая ML | LLM |
|--|----------------|-----|
| Размер | MB–GB | GB–TB (7B = ~14GB fp16) |
| Inference | CPU часто достаточно | GPU почти всегда |
| Латентность | ms | сотни ms — секунды (autoregressive) |
| Входные данные | структурированные | неструктурированный текст |
| Выход | число/класс | текст (непредсказуемый) |
| Оценка качества | accuracy, F1, AUC | субъективна, нужен human eval / LLM-as-judge |
| Адаптация | retrain | prompt engineering / RAG / fine-tuning |

## Три подхода к адаптации LLM

### 1. Prompt Engineering (начать здесь)

Изменить поведение без изменения весов.
Дёшево, быстро, нет GPU. Попробовать первым.

```python
# System prompt определяет роль и поведение
system = """Ты — технический ассистент DevOps команды.
Отвечай кратко, используй примеры команд.
Если не знаешь — скажи об этом явно."""

# Few-shot примеры направляют формат ответа
user = """Как проверить почему Pod в Pending статусе?

Пример ответа:
Q: Как посмотреть логи?
A: kubectl logs <pod-name> [-c <container>] [-f для follow]

Q: Как проверить почему Pod в Pending статусе?
A:"""
```

### 2. RAG (Retrieval-Augmented Generation)

Когда нужны актуальные или приватные знания которых нет в модели.

```
Вопрос пользователя
    │
    ▼
Embedding модель → вектор запроса
    │
    ▼
Vector Store (Qdrant, pgvector, Chroma)
    │ top-K похожих документов
    ▼
LLM(system_prompt + найденные документы + вопрос)
    │
    ▼
Ответ со ссылками на источники
```

```python
from qdrant_client import QdrantClient
from openai import OpenAI

client = QdrantClient(url="http://localhost:6333")
openai = OpenAI()

def rag_answer(question: str) -> str:
    # 1. embed вопрос
    embedding = openai.embeddings.create(
        model="text-embedding-3-small",
        input=question
    ).data[0].embedding

    # 2. найти похожие документы
    results = client.search(
        collection_name="docs",
        query_vector=embedding,
        limit=5
    )
    context = "\n".join(r.payload["text"] for r in results)

    # 3. ответить с контекстом
    response = openai.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": f"Отвечай на основе контекста:\n{context}"},
            {"role": "user", "content": question}
        ]
    )
    return response.choices[0].message.content
```

### 3. Fine-tuning (когда RAG недостаточно)

Когда нужно изменить стиль/формат ответа или специализировать под домен.

**LoRA (Low-Rank Adaptation)** — обучаются только небольшие матрицы адаптеров,
не все веса. 10–100x меньше GPU памяти и времени чем full fine-tuning.

**QLoRA** — LoRA + квантизация базовой модели до 4bit. Позволяет fine-tune
13B модели на RTX 4090 (24GB VRAM).

```python
# QLoRA с библиотекой peft
from peft import get_peft_model, LoraConfig, TaskType
from transformers import AutoModelForCausalLM, BitsAndBytesConfig

# квантизация базовой модели до 4bit
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_use_double_quant=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.bfloat16
)

model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-3-8B",
    quantization_config=bnb_config,
    device_map="auto"
)

# конфигурация LoRA адаптера
lora_config = LoraConfig(
    task_type=TaskType.CAUSAL_LM,
    r=16,           # rank — чем выше, тем больше параметров
    lora_alpha=32,
    lora_dropout=0.1,
    target_modules=["q_proj", "v_proj"]  # какие слои адаптировать
)

model = get_peft_model(model, lora_config)
model.print_trainable_parameters()
# trainable params: 6.7M || all params: 8B || trainable%: 0.083%
```

## Serving LLM в продакшне

### vLLM — оптимизированный inference сервер

```bash
# запустить API совместимый с OpenAI
docker run --runtime nvidia --gpus all \
  -p 8000:8000 \
  vllm/vllm-openai:latest \
  --model meta-llama/Llama-3.1-8B-Instruct \
  --tensor-parallel-size 1 \
  --max-model-len 8192

# тест
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Llama-3.1-8B-Instruct",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

**PagedAttention** — ключевая оптимизация vLLM: KV cache хранится в страницах
как виртуальная память. Позволяет обрабатывать больше параллельных запросов
и применять continuous batching (новые запросы добавляются без ожидания
завершения текущего batch).

### Ключевые параметры производительности

```
Throughput (токен/сек) — сколько токенов генерируется для всех пользователей
TTFT (Time To First Token) — время до первого токена (важно для UX)
ITL (Inter-Token Latency) — время между токенами (влияет на плавность)

Batching: статический (ждём пока batch заполнится) vs 
          continuous (добавляем запросы на лету) ← vLLM использует continuous
```

## Оценка качества LLM (Evaluation)

```python
# RAGAS — оценка RAG пайплайна
from ragas import evaluate
from ragas.metrics import faithfulness, answer_relevancy, context_precision

results = evaluate(
    dataset=test_dataset,   # вопросы + правильные ответы + контекст
    metrics=[faithfulness, answer_relevancy, context_precision]
)
# faithfulness: ответ основан на контексте?
# answer_relevancy: ответ релевантен вопросу?
# context_precision: контекст содержит нужное?
```

## Langfuse — трейсинг LLM приложений (open-source)

```python
from langfuse import Langfuse
from langfuse.openai import openai   # патчит openai клиент

langfuse = Langfuse(
    public_key="pk-...",
    secret_key="sk-...",
    host="http://localhost:3000"   # self-hosted
)

# все вызовы openai автоматически трейсятся
response = openai.chat.completions.create(
    model="gpt-4o-mini",
    messages=[{"role": "user", "content": "Hello"}],
    name="my-trace",    # имя в UI
)
# в Langfuse UI: latency, tokens, cost, input/output
```

## Guardrails — безопасность вывода

```python
# nemo-guardrails (NVIDIA, open-source)
# или: llm-guard, guardrails-ai

from guardrails import Guard
from guardrails.hub import ToxicLanguage, DetectPII

guard = Guard().use_many(
    ToxicLanguage(on_fail="exception"),
    DetectPII(pii_entities=["EMAIL", "PHONE"], on_fail="fix")
)

response = guard(
    openai.chat.completions.create,
    prompt="...",
    model="gpt-4o-mini"
)
```
