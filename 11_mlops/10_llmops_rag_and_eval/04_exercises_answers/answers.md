# Ответы — LLMOps

Упражнения: [../03_exercises/README.md](../03_exercises/README.md).
Стенд: 🐳 Tier 1 — Docker, без GPU. LLM — локальный Ollama с моделью
`qwen2.5:0.5b` (или OpenAI API, если есть ключ).

Общая подготовка (один раз):

```bash
docker run -d --name ollama -p 11434:11434 \
  -v ollama:/root/.ollama ollama/ollama:latest
docker exec ollama ollama pull qwen2.5:0.5b

python3 -m venv .venv && . .venv/bin/activate
pip install qdrant-client sentence-transformers openai langfuse

# Переменные для OpenAI-клиента (читаются из окружения)
export OPENAI_BASE_URL=http://localhost:11434/v1
export OPENAI_API_KEY=ollama
export LLM_MODEL=qwen2.5:0.5b
# Для OpenAI вместо этого: unset OPENAI_BASE_URL;
# OPENAI_API_KEY=sk-...; LLM_MODEL=gpt-4o-mini
```

## Упражнение 01 — RAG pipeline с Qdrant

Готовое решение TODO — [rag_answer.py](./rag_answer.py): тот же поиск,
что в условии, плюс шаг «найденные документы → контекст в system prompt
→ ответ LLM».

```bash
docker run -d --name qdrant -p 6333:6333 qdrant/qdrant:latest
python rag_answer.py
```

Ожидаемый вывод:

```text
Query: How do I monitor my application metrics?

Most relevant docs:
  Score 0.458: Prometheus scrapes metrics from /metrics endpoints. PromQL is its query language.
  Score 0.165: ArgoCD implements GitOps for Kubernetes. It syncs cluster state from Git.

Answer: Prometheus scrapes metrics from /metrics endpoints. ...
```

Почему так:
- Документы и запрос кодируются одной embedding-моделью
  (`all-MiniLM-L6-v2`, 384 измерения), поэтому размер коллекции —
  `size=384`; cosine-близость ставит документ про Prometheus первым.
- Инструкция «отвечай только из контекста» заставляет модель опираться на
  найденное, а не на свои знания; низкая `temperature` уменьшает
  разброс ответов.
- Поиск — через `query_points(...).points`: метод `search()` в новых
  версиях qdrant-client удалён.

Полный пример с классом и несколькими вопросами —
[../02_examples/rag_pipeline.py](../02_examples/rag_pipeline.py) (для
Ollama раскомментируйте `openai_base_url` и `llm_model`). На нём видно
ограничение маленькой модели: даже с верным контекстом она иногда
ошибается (например, отвечает про ArgoCD на вопрос о мониторинге) —
поэтому RAG оценивают метриками (RAGAS, см. теорию), а не на глаз.

## Упражнение 02 — Prompt Engineering: system prompt и few-shot

Скрипт `prompt_engineering.py` — как в условии; модель и адрес берутся
из переменных окружения из «Общей подготовки».

```bash
python prompt_engineering.py
```

Ожидаемый вывод (текст каждый раз немного другой):

```text
BAD: Kubernetes is a open-source container orchestration platform that
allows for automatic container deployment and scaling of applications.
Kubernetes consists of the following components:

1. Pods: A po

GOOD: A Deployment is a managed set of Kubernetes resources. Use
`kubectl get deployments` to list them.
```

Почему так:
- Без system prompt модель отвечает длинно и без структуры (вывод обрезан
  до 200 символов).
- System prompt задаёт роль и формат («2-3 предложения + команда»), а
  few-shot пара user/assistant показывает пример нужного ответа — модель
  копирует его стиль: коротко и с командой `kubectl`.
- Содержание у маленькой модели может быть неточным — prompt управляет
  формой ответа, а не знаниями модели.

## Упражнение 03 — Трейсинг LLM с Langfuse

```bash
git clone --depth 1 https://github.com/langfuse/langfuse.git
cd langfuse
docker compose up -d
docker compose ps
```

В UI `http://localhost:3000`: зарегистрироваться → создать организацию и
проект → Settings → API Keys → создать ключи. Затем:

```bash
export LANGFUSE_PUBLIC_KEY=pk-lf-...
export LANGFUSE_SECRET_KEY=sk-lf-...
export LANGFUSE_HOST=http://localhost:3000
python langfuse_demo.py
```

Ожидаемый вывод:

```text
GitOps is a way of managing infrastructure and applications where Git
is the single source of truth ...
```

В Langfuse UI → Tracing появится trace `gitops-question` с input/output,
latency и числом токенов.

Убрать стенд:

```bash
docker compose down -v
```

Почему так:
- `from langfuse.openai import openai` — обёртка над openai-клиентом:
  каждый вызов `chat.completions.create` автоматически пишется в trace;
  аргумент `name` задаёт имя trace в UI.
- SDK отправляет трейсы в фоне пачками; `get_client().flush()` в конце
  короткого скрипта нужен, чтобы они ушли до выхода процесса.
- Langfuse v3 — это web + worker + PostgreSQL + ClickHouse + Redis + S3,
  поэтому одного `docker run` недостаточно; официальный compose поднимает
  всё сразу. Стенд тяжёлый (несколько ГБ RAM) — после упражнения его
  лучше удалить.
