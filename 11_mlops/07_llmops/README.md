# 07. LLMOps — LLM в продакшне

## Зачем
LLM-приложение ломается иначе, чем обычная модель: ответ «выглядит
правильно», но выдуман; стоимость зависит от токенов; качество меняется
от правки промпта. Тема разбирает, как адаптировать LLM под задачу
(prompt engineering → RAG → fine-tuning), как его обслуживать (vLLM на
GPU, Ollama на CPU), оценивать (RAGAS, LLM-as-judge), трейсить
(Langfuse) и ограничивать вывод (guardrails).

## Пререквизиты
- [04_model_serving](../04_model_serving/) — OpenAI-совместимый API,
  vLLM и почему для него нужна GPU (упражнение 01 там поднимает Ollama).
- [3_containers](../../3_containers/) — Docker и Docker Compose.
- Python на уровне скриптов с `pip install` и venv — см. соседний
  репозиторий
  [4_python_my_knowledgebase/1_python](../../../4_python_my_knowledgebase/1_python/).
- Git: в упражнении 03 клонируется репозиторий Langfuse; в этой базе Git
  не преподаётся, см.
  [01_git_essentials](../../../4_python_my_knowledgebase/0_tooling_and_workflow/01_git_essentials/)
  (соседний репозиторий). Достаточно `git clone`.

## Файлы
- [01_theory/llmops.md](./01_theory/llmops.md) — отличия LLM от обычной
  модели, prompt engineering, RAG, fine-tuning (LoRA/QLoRA), serving
  (vLLM, только GPU), оценка, Langfuse, guardrails.
- [02_examples/rag_pipeline.py](./02_examples/rag_pipeline.py) — RAG
  pipeline: Qdrant + sentence-transformers + LLM через OpenAI-совместимый
  API (OpenAI или Ollama).
- [03_exercises/README.md](./03_exercises/README.md) — 3 упражнения: RAG
  с Qdrant, system prompt и few-shot, трейсинг в Langfuse; 🐳 Tier 1,
  LLM на CPU через Ollama.
- [04_exercises_answers/answers.md](./04_exercises_answers/answers.md) —
  ответы с ожидаемым выводом;
  [04_exercises_answers/rag_answer.py](./04_exercises_answers/rag_answer.py)
  — решение TODO из упражнения 01.

## Как проходить
1. Теория до раздела про fine-tuning.
2. Упражнения 01 и 02 (нужны Qdrant и Ollama в Docker), сверка с
   ответами; затем запустить `02_examples/rag_pipeline.py`.
3. Дочитать теорию (serving, оценка, Langfuse, guardrails) и сделать
   упражнение 03. Стенд Langfuse тяжёлый (несколько ГБ RAM) — после
   упражнения удалить.

## Когда двигаться дальше
- Можете собрать RAG: проиндексировать документы, найти релевантные и
  передать их в LLM как контекст.
- Можете объяснить, когда хватает промпта, когда нужен RAG, а когда
  fine-tuning.
- Можете показать trace LLM-вызова (latency, токены) и объяснить, зачем
  он нужен в продакшне.

Далее: [08_gpu_infrastructure](../08_gpu_infrastructure/).
