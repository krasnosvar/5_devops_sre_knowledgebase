# Раздел 10. MLOps и LLMOps

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
   для ML (подробнее в следующей секции).

## Как проходить

01 → 02 (понять lifecycle и эксперименты) → 04 (как модель идёт в прод) →
03 (пайплайны обучения) → 06 (мониторинг) → 05, 07, 08 по необходимости.
07 (LLMOps) можно читать отдельно как самостоятельный трек.

## Упражнения — тиры

🐳 Tier 1: MLflow + MinIO в Docker Compose; vLLM с открытой моделью локально
🖥 Tier 2: Kubeflow Pipelines в kind; BentoML + Triton в k3d
☁️ Tier 3: распределённое обучение на AWS (Spot GPU instances)
