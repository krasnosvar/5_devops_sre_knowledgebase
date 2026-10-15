# Раздел 11. MLOps и LLMOps

ML в продакшне — это DevOps плюс работа с данными и моделями как артефактами.
Здесь: lifecycle модели от эксперимента до деплоя, инфраструктура для обучения
и инференса, специфика LLM и GPU.

## Чем MLOps отличается от обычного DevOps

| DevOps | MLOps |
|--------|-------|
| Артефакт — код / бинарник | Артефакт — код + данные + модель + конфиг |
| Тест — unit/integration | Тест + оценка качества модели (метрики ML) |
| Деплой = новая версия кода | Деплой = новая версия кода, данных или модели |
| Мониторинг = uptime/latency | Мониторинг + data drift + model drift |
| Воспроизводимость из кода | Воспроизводимость из кода + данных + seed |

## Пререквизиты

- [3_containers](../3_containers/) — образы и Docker Compose: все стенды
  раздела поднимаются в контейнерах.
- [4_kubernetes](../4_kubernetes/) — для частей про KServe, Kubeflow,
  Training Operator и GPU в кластере (Deployment, Service, CRD, Helm).
- [6_cicd](../6_cicd/) — понятия pipeline и артефакта; в MLOps они
  переносятся на данные и модели.
- [8_observability](../8_observability/) — Prometheus и Grafana для
  мониторинга моделей и GPU.
- Python на уровне чтения и запуска скриптов — соседний репозиторий
  [4_python_my_knowledgebase](../../4_python_my_knowledgebase/).

## Подразделы

1. [01_ml_lifecycle](./01_ml_lifecycle/) — полный цикл модели: постановка задачи,
   подготовка данных, обучение, оценка, деплой, мониторинг, переобучение; где
   DevOps-инженер включается в этот процесс и что ему нужно понимать.

2. [02_experiment_tracking](./02_experiment_tracking/) — отслеживание экспериментов:
   MLflow (runs, artifacts, model registry), Weights & Biases, DVC (Data Version Control)
   для версионирования данных и моделей; как хранить эксперименты в Git-совместимом
   виде.

3. [03_training_pipelines](./03_training_pipelines/) — пайплайны обучения:
   Kubeflow Pipelines (k8s-native), Apache Airflow (общий DAG-оркестратор),
   Prefect и Metaflow (Python-first); когда использовать каждый; запуск
   distributed training (PyTorch DDP, Horovod) в k8s через KubeFlow Training Operator.

4. [04_model_serving](./04_model_serving/) — подача модели:
   - классические модели: BentoML, Seldon Core, KServe (KFServing)
   - LLM inference: vLLM, Triton Inference Server, TGI (Text Generation Inference)
   - паттерны: batching (динамический и статический), caching (KV cache, semantic cache),
     A/B тестирование моделей, canary деплой для моделей.

5. [05_feature_stores](./05_feature_stores/) — feature store: зачем нужен, что
   решает (training-serving skew); Feast (open-source); offline store (Parquet, BigQuery)
   vs online store (Redis, DynamoDB); когда feature store оправдан.

6. [06_model_monitoring](./06_model_monitoring/) — мониторинг моделей в продакшне:
   data drift (PSI, KL divergence, Kolmogorov-Smirnov); concept drift; Evidently AI
   как open-source инструмент; интеграция с Grafana; когда триггерить переобучение.

7. [07_llmops](./07_llmops/) — специфика LLM в продакшне:
   - fine-tuning (LoRA, QLoRA, full fine-tuning): когда нужно, когда достаточно
     prompt engineering
   - RAG (Retrieval-Augmented Generation): pipeline, vector stores (Qdrant, Pgvector,
     Chroma), chunking стратегии, re-ranking
   - оценка качества LLM: автоматические метрики (RAGAS, G-Eval), human eval,
     LLM-as-judge; Langfuse и LangSmith для трейсинга LLM-приложений
   - guardrails и safety: output validation, PII detection, moderation.

8. [08_gpu_infrastructure](./08_gpu_infrastructure/) — GPU инфраструктура
   для ML: классы GPU, VRAM и bandwidth, GPU в Kubernetes (device plugin,
   GPU Operator, MIG, time-slicing), облачные инстансы, мониторинг.

## Как проходить

01 → 02 (понять lifecycle и эксперименты) → 04 (как модель идёт в прод) →
03 (пайплайны обучения) → 06 (мониторинг) → 05, 07, 08 по необходимости.
07 (LLMOps) можно читать отдельно как самостоятельный трек.

## Упражнения — тиры

🐳 Tier 1: MLflow + S3-хранилище (SeaweedFS) в Docker Compose; LLM на CPU
через Ollama (OpenAI-совместимый API), BentoML, A/B через nginx
([04_model_serving](./04_model_serving/)); RAG, промпты, Langfuse
([07_llmops](./07_llmops/)). Образ vLLM требует NVIDIA GPU — без неё
используется Ollama или llama.cpp server.
🖥 Tier 2: Kubeflow Pipelines и KServe в локальном кластере — описаны в
теории, отдельных лаб пока нет.
☁️ Tier 3: GPU-инстансы в облаке для vLLM и распределённого обучения
([08_gpu_infrastructure](./08_gpu_infrastructure/)).

## Когда двигаться дальше

- Можете поднять MLflow с S3-хранилищем, залогировать run и
  зарегистрировать модель.
- Можете отдать модель через API (BentoML или OpenAI-совместимый LLM
  сервер) и разделить трафик между двумя версиями.
- Можете объяснить, как обнаружить data drift и когда переобучать
  модель.
- Можете собрать простой RAG и показать trace LLM-вызова.

Далее: [12_interview_questions_prep](../12_interview_questions_prep/).
