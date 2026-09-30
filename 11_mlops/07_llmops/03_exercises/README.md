# Упражнения — LLMOps

Стенд: 🐳 Tier 1 — Docker (CPU-only модели)

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

# Создать коллекцию
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
results = client.search("devops_docs", query_vector=query_vector, limit=2)

print("Query:", query)
print("\nMost relevant docs:")
for r in results:
    print(f"  Score {r.score:.3f}: {r.payload['text']}")

# TODO: передать найденные документы в LLM как контекст
```

## 02 — Prompt Engineering: system prompt и few-shot

```python
# prompt_engineering.py
# pip install openai  (или использовать Ollama локально)

import os
from openai import OpenAI

# Если нет OpenAI ключа — использовать Ollama:
# client = OpenAI(api_key="ollama", base_url="http://localhost:11434/v1")
client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])

# Плохой prompt
bad_response = client.chat.completions.create(
    model="gpt-4o-mini",
    messages=[{"role": "user", "content": "explain kubernetes"}]
)

# Хороший prompt с system + few-shot
good_response = client.chat.completions.create(
    model="gpt-4o-mini",
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
# Поднять Langfuse (self-hosted observability для LLM)
docker run -d --name langfuse -p 3000:3000 \
  -e NEXTAUTH_SECRET=mysecret \
  -e SALT=mysalt \
  -e DATABASE_URL=sqlite:///langfuse.db \
  langfuse/langfuse:latest

# UI: http://localhost:3000
```

```python
# langfuse_demo.py
# pip install langfuse openai

from langfuse import Langfuse
from langfuse.openai import openai   # monkey-patches openai клиент

langfuse = Langfuse(
    public_key="pk-lf-...",    # из Langfuse UI
    secret_key="sk-lf-...",
    host="http://localhost:3000"
)

# Все вызовы openai теперь автоматически трейсируются
response = openai.chat.completions.create(
    model="gpt-4o-mini",
    messages=[{"role": "user", "content": "What is GitOps?"}],
    name="gitops-question"   # имя в Langfuse UI
)

print(response.choices[0].message.content)
# Посмотреть trace в http://localhost:3000
```
