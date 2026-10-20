# 10. LLMOps: RAG, векторные БД (Qdrant), трейсинг и оценка (RAGAS)

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка
> по стратегиям чанкинга, Hybrid Search (`Dense + BM25 + RRF`) в
> `Qdrant`, метрикам `Hit@k`/`MRR`/`RAGAS` и трейсингу `Langfuse`.

## Зачем

Даже самая сильная локальная LLM не знает содержимого ваших личных
медицинских анализов, налоговых уведомлений ФНС или домашних заметок —
а если попытаться засунуть 500 документов целиком в промпт, память
`KV-cache` закончится, латентность вырастет до минут, а модель потеряет
факты в середине контекста (**Lost in the Middle**).

Раздел учит строить продакшен-уровень **RAG (Retrieval-Augmented
Generation)**: правильно резать документы на чанки, комбинировать
векторный поиск (`bge-m3`) с точным поиском по номерам/датам (`BM25` +
фильтры `Qdrant`), оценивать ретривер (`Hit@k`, `MRR`) и генератор
(`Faithfulness`), а также трассировать каждый шаг в **Langfuse**.

## Пререквизиты

- [02. Экосистема Hugging Face](../02_huggingface_and_hubs/) (эмбеддинги
  и реранкеры).
- [06. Деплой и инференс моделей](../06_model_serving/) (`Ollama` /
  `llama.cpp` / `vLLM`).

## Файлы

- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка по RAG, Qdrant и метрикам
  оценки.
- `01_theory/`
  - [llmops.md](./01_theory/llmops.md) — Prompting vs RAG vs Fine-Tuning,
    архитектура Hybrid RAG, чанкинг, индексы `HNSW` в Qdrant, реранкинг,
    метрики `Hit@k` / `MRR` / `RAGAS`, трейсинг `Langfuse` и 10 Q&A.
- `02_examples/`
  - [rag_pipeline.py](./02_examples/rag_pipeline.py) — полный пайплайн
    индексации и поиска с `Qdrant` и локальной LLM.
- `03_exercises/`
  - [README.md](./03_exercises/README.md) — практические задания.
- `04_exercises_answers/`
  - [answers.md](./04_exercises_answers/answers.md) — разбор решений.

## Как проходить

1. Прочитайте [теорию](./01_theory/llmops.md).
2. Разберите код [02_examples/rag_pipeline.py](./02_examples/rag_pipeline.py)
   и выполните упражнения из [03_exercises/README.md](./03_exercises/README.md).

## Когда двигаться дальше

Вы готовы к разделу [11. AI DevSecOps: безопасность ML и LLM](../11_ml_and_llm_security/),
если:
- понимаете, почему чистый векторный поиск (`Dense`) плохо ищет точные
  номера договоров, КБК и артикулы, и как помогает `Hybrid Search`;
- знаете разницу между Bi-Encoder (эмбеддер) и Cross-Encoder (реранкер);
- умеете разделять ошибки Retrieval (`Context Recall`) и ошибки
  Generation (`Faithfulness`).
