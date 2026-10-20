# Упражнения — LLMOps

Стенд: 🐳 Tier 1 — Docker (CPU-only модели)

LLM для упражнений: OpenAI API (нужен ключ) или локальный Ollama с
OpenAI-совместимым API на CPU:

```bash
docker run -d --name ollama -p 11434:11434 \
  -v ollama:/root/.ollama ollama/ollama:latest
docker exec ollama ollama pull qwen2.5:0.5b
```

## 01 — RAG pipeline с Qdrant

```bash
# Поднять Qdrant — векторная база данных
docker run -d --name qdrant -p 6333:6333 qdrant/qdrant:latest
```

```python
# rag_demo.py
# pip install qdrant-client sentence-transformers openai

from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct
from sentence_transformers import SentenceTransformer

# Инициализация
client = QdrantClient("localhost", port=6333)
model = SentenceTransformer("all-MiniLM-L6-v2")   # маленькая бесплатная модель

# Создать коллекцию (при повторном запуске — пересоздать)
if client.collection_exists("devops_docs"):
    client.delete_collection("devops_docs")
client.create_collection("devops_docs",
    vectors_config=VectorParams(size=384, distance=Distance.COSINE))

# Добавить документы (ваша база знаний)
docs = [
    "Kubernetes is a container orchestration platform. kubectl is the CLI tool.",
    "Docker is used to build and run containers. docker-compose is for multi-container apps.",
    "Prometheus scrapes metrics from /metrics endpoints. PromQL is its query language.",
    "Terraform manages infrastructure as code. State is stored in tfstate files.",
    "ArgoCD implements GitOps for Kubernetes. It syncs cluster state from Git.",
]

vectors = model.encode(docs).tolist()
client.upsert("devops_docs", points=[
    PointStruct(id=i, vector=v, payload={"text": d})
    for i, (v, d) in enumerate(zip(vectors, docs))
])

# RAG: найти похожие документы по запросу
query = "How do I monitor my application metrics?"
query_vector = model.encode(query).tolist()
# query_points — актуальный API (client.search() удалён)
results = client.query_points("devops_docs", query=query_vector,
                              limit=2).points

print("Query:", query)
print("\nMost relevant docs:")
for r in results:
    print(f"  Score {r.score:.3f}: {r.payload['text']}")

# TODO: передать найденные документы в LLM как контекст
```

**Задача:** доделать TODO — передать найденные документы в LLM как
контекст и получить ответ на `query`.

## 02 — Prompt Engineering: system prompt и few-shot

```python
# prompt_engineering.py
# pip install openai  (или использовать Ollama локально)

import os
from openai import OpenAI

# OpenAI: OPENAI_API_KEY=sk-... LLM_MODEL=gpt-4o-mini
# Ollama:  OPENAI_API_KEY=ollama LLM_MODEL=qwen2.5:0.5b
#          OPENAI_BASE_URL=http://localhost:11434/v1
# (OPENAI_BASE_URL клиент читает из окружения сам)
client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])
MODEL = os.environ["LLM_MODEL"]

# Плохой prompt
bad_response = client.chat.completions.create(
    model=MODEL,
    messages=[{"role": "user", "content": "explain kubernetes"}]
)

# Хороший prompt с system + few-shot
good_response = client.chat.completions.create(
    model=MODEL,
    messages=[
        {
            "role": "system",
            "content": """You are a DevOps assistant. Answer concisely in 2-3 sentences.
Always include a practical example command."""
        },
        {
            "role": "user",
            "content": "What is a Pod in Kubernetes?"
        },
        {
            "role": "assistant",
            "content": "A Pod is the smallest deployable unit in Kubernetes, containing one or more containers sharing network and storage. Use `kubectl run nginx --image=nginx` to create one."
        },
        {
            "role": "user",
            "content": "What is a Deployment?"
        }
    ]
)

print("BAD:", bad_response.choices[0].message.content[:200])
print("\nGOOD:", good_response.choices[0].message.content)
```

## 03 — Трейсинг LLM с Langfuse

```bash
# Поднять Langfuse (self-hosted observability для LLM).
# Одного контейнера мало: Langfuse v3 состоит из web + worker и
# требует PostgreSQL, ClickHouse, Redis и S3-совместимое хранилище
# (SQLite не поддерживается). Официальный docker-compose поднимает
# всё вместе:
git clone --depth 1 https://github.com/langfuse/langfuse.git
cd langfuse
docker compose up -d

# UI: http://localhost:3000 — зарегистрироваться, создать проект,
# в Settings → API Keys получить public/secret key
```

```python
# langfuse_demo.py
# pip install langfuse openai
# Ключи и адрес Langfuse SDK берёт из переменных окружения:
#   LANGFUSE_PUBLIC_KEY=pk-lf-...  LANGFUSE_SECRET_KEY=sk-lf-...
#   LANGFUSE_HOST=http://localhost:3000
# Для Ollama вместо OpenAI:
#   OPENAI_BASE_URL=http://localhost:11434/v1  OPENAI_API_KEY=ollama

import os

from langfuse import get_client
from langfuse.openai import openai   # обёртка над openai-клиентом

# Все вызовы openai теперь автоматически трейсируются
response = openai.chat.completions.create(
    model=os.environ["LLM_MODEL"],     # gpt-4o-mini или qwen2.5:0.5b
    messages=[{"role": "user", "content": "What is GitOps?"}],
    name="gitops-question"   # имя в Langfuse UI
)

print(response.choices[0].message.content)
get_client().flush()   # отправить трейсы до выхода из скрипта
# Посмотреть trace в http://localhost:3000
```
