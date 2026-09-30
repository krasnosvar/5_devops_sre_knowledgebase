"""
RAG (Retrieval-Augmented Generation) pipeline
pip install qdrant-client sentence-transformers openai

Требования:
- Qdrant: docker run -d -p 6333:6333 qdrant/qdrant
- OpenAI key или Ollama локально
"""

from dataclasses import dataclass
from typing import Optional
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct
from sentence_transformers import SentenceTransformer
from openai import OpenAI


@dataclass
class Document:
    id: int
    text: str
    metadata: dict


class RAGPipeline:
    def __init__(
        self,
        qdrant_url: str = "http://localhost:6333",
        collection_name: str = "knowledge_base",
        embedding_model: str = "all-MiniLM-L6-v2",
        llm_model: str = "gpt-4o-mini",
        openai_base_url: Optional[str] = None,
    ):
        self.qdrant = QdrantClient(url=qdrant_url)
        self.collection = collection_name
        self.embedder = SentenceTransformer(embedding_model)
        self.llm = OpenAI(
            base_url=openai_base_url,
            api_key="ollama" if openai_base_url else None
        )
        self.llm_model = llm_model
        self._vector_size = self.embedder.get_sentence_embedding_dimension()

    def setup_collection(self):
        """Создать коллекцию в Qdrant."""
        self.qdrant.recreate_collection(
            collection_name=self.collection,
            vectors_config=VectorParams(
                size=self._vector_size,
                distance=Distance.COSINE
            )
        )

    def ingest(self, documents: list[Document]):
        """Загрузить документы в векторную базу."""
        texts = [doc.text for doc in documents]
        vectors = self.embedder.encode(texts, show_progress_bar=True).tolist()

        self.qdrant.upsert(
            collection_name=self.collection,
            points=[
                PointStruct(
                    id=doc.id,
                    vector=vec,
                    payload={"text": doc.text, **doc.metadata}
                )
                for doc, vec in zip(documents, vectors)
            ]
        )
        print(f"Ingested {len(documents)} documents")

    def retrieve(self, query: str, top_k: int = 3) -> list[dict]:
        """Найти релевантные документы по запросу."""
        query_vector = self.embedder.encode(query).tolist()
        results = self.qdrant.search(
            collection_name=self.collection,
            query_vector=query_vector,
            limit=top_k,
            with_payload=True,
        )
        return [
            {"text": r.payload["text"], "score": r.score, "id": r.id}
            for r in results
        ]

    def answer(self, question: str, top_k: int = 3) -> dict:
        """Ответить на вопрос используя RAG."""
        docs = self.retrieve(question, top_k=top_k)
        context = "\n\n".join(f"[{i+1}] {d['text']}" for i, d in enumerate(docs))

        response = self.llm.chat.completions.create(
            model=self.llm_model,
            messages=[
                {
                    "role": "system",
                    "content": (
                        "Answer based on the provided context. "
                        "If the answer is not in the context, say so clearly. "
                        "Be concise."
                    )
                },
                {
                    "role": "user",
                    "content": f"Context:\n{context}\n\nQuestion: {question}"
                }
            ],
            temperature=0.1,
            max_tokens=500,
        )

        return {
            "answer": response.choices[0].message.content,
            "sources": docs,
            "tokens_used": response.usage.total_tokens,
        }


# ── Demo ──────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    rag = RAGPipeline(
        # Для Ollama вместо OpenAI:
        # openai_base_url="http://localhost:11434/v1",
        # llm_model="llama3.1",
    )
    rag.setup_collection()

    docs = [
        Document(1, "Kubernetes is an open-source container orchestration platform. "
                    "kubectl is the command-line tool for managing k8s clusters.",
                 {"topic": "kubernetes", "source": "docs"}),
        Document(2, "Docker containers package applications with their dependencies. "
                    "docker-compose is used for multi-container applications.",
                 {"topic": "docker", "source": "docs"}),
        Document(3, "Prometheus is a monitoring system that scrapes metrics from /metrics endpoints. "
                    "Grafana visualizes Prometheus data in dashboards.",
                 {"topic": "monitoring", "source": "docs"}),
        Document(4, "Terraform manages infrastructure as code using HCL. "
                    "State files track what Terraform has created.",
                 {"topic": "iac", "source": "docs"}),
        Document(5, "ArgoCD implements GitOps for Kubernetes by syncing cluster state from Git. "
                    "It automatically detects and corrects drift.",
                 {"topic": "gitops", "source": "docs"}),
    ]

    rag.ingest(docs)

    questions = [
        "How do I monitor my Kubernetes cluster?",
        "What is GitOps and how does ArgoCD work?",
        "How does Terraform track infrastructure state?",
    ]

    for q in questions:
        print(f"\nQ: {q}")
        result = rag.answer(q)
        print(f"A: {result['answer']}")
        print(f"   Sources used: {[d['score']:.3f for d in result['sources']]}")
        print(f"   Tokens: {result['tokens_used']}")
