"""Ответ к упражнению 01: RAG на Qdrant + LLM через OpenAI-совместимый API.

Запуск (Ollama на CPU):
    OPENAI_BASE_URL=http://localhost:11434/v1 OPENAI_API_KEY=ollama \
    LLM_MODEL=qwen2.5:0.5b python rag_answer.py
Для OpenAI: OPENAI_API_KEY=sk-... LLM_MODEL=gpt-4o-mini python rag_answer.py
"""
import os

from openai import OpenAI
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, PointStruct, VectorParams
from sentence_transformers import SentenceTransformer

COLLECTION = "devops_docs"
LLM_MODEL = os.environ["LLM_MODEL"]  # явно, без значения по умолчанию

client = QdrantClient("localhost", port=6333)
embedder = SentenceTransformer("all-MiniLM-L6-v2")  # 384-мерные векторы
# OPENAI_API_KEY / OPENAI_BASE_URL клиент читает из окружения
llm = OpenAI()

if client.collection_exists(COLLECTION):
    client.delete_collection(COLLECTION)
client.create_collection(
    COLLECTION,
    vectors_config=VectorParams(size=384, distance=Distance.COSINE),
)

docs = [
    "Kubernetes is a container orchestration platform. kubectl is the CLI tool.",
    "Docker is used to build and run containers. docker-compose is for multi-container apps.",
    "Prometheus scrapes metrics from /metrics endpoints. PromQL is its query language.",
    "Terraform manages infrastructure as code. State is stored in tfstate files.",
    "ArgoCD implements GitOps for Kubernetes. It syncs cluster state from Git.",
]
vectors = embedder.encode(docs).tolist()
client.upsert(COLLECTION, points=[
    PointStruct(id=i, vector=v, payload={"text": d})
    for i, (v, d) in enumerate(zip(vectors, docs))
])

query = "How do I monitor my application metrics?"
hits = client.query_points(
    COLLECTION, query=embedder.encode(query).tolist(), limit=2
).points

print("Query:", query)
print("\nMost relevant docs:")
for h in hits:
    print(f"  Score {h.score:.3f}: {h.payload['text']}")

# Шаг, который был TODO: найденные документы -> контекст для LLM
context = "\n".join(f"[{i + 1}] {h.payload['text']}" for i, h in enumerate(hits))
response = llm.chat.completions.create(
    model=LLM_MODEL,
    messages=[
        {"role": "system",
         "content": "Answer only from the context. If the answer is not "
                    "in the context, say you don't know.\n\n"
                    f"Context:\n{context}"},
        {"role": "user", "content": query},
    ],
    temperature=0.1,
    max_tokens=150,
)
print("\nAnswer:", response.choices[0].message.content)
