# Раздел 11. MLOps и LLMOps

ML в продакшне — это классический DevOps/SRE плюс управление данными,
весами моделей, промптами и векторными индексами как версионируемыми
артефактами. В этом разделе объединены две дополняющие друг друга
дисциплины — **классический MLOps** (табличные модели, градиентный
бустинг, компактные трансформеры в ONNX) и **LLMOps** (локальные LLM,
RAG, квантование, защита от инъекций) — с выходом на единый сквозной
пет-проект в локальном кластере Kubernetes (`k3d`).

---

## Где пересекаются классический MLOps и LLMOps

Обе дисциплины решают одну задачу — надёжно довести модель до продакшна
и следить, чтобы она не деградировала. Различаются конкретные артефакты
и метрики на каждом этапе:

| Этап / Слой | Классический MLOps | LLMOps |
| :--- | :--- | :--- |
| **Данные** | Таблицы, признаки, контракты `Pandera` / `Great Expectations`, `DVC` | Корпус документов (PDF, фото/OCR, заметки), чанкинг, SFT-датасеты |
| **Эксперименты** | Гиперпараметры, фичи, метрики в `MLflow` | Промпты, размер чанка, `top-k`, модель/квантование, температура |
| **Артефакт** | Веса модели в реестре (`safetensors`, `ONNX`) | Базовая модель (`GGUF`) + LoRA-адаптер + системный промпт + векторный индекс |
| **Оценка (Eval)** | `Accuracy`, `F1`, `ROC-AUC`, `PR-AUC` на отложенной выборке | Retrieval (`Hit@K`, `MRR`), `RAGAS`, `LLM-as-a-Judge`, детерминированные проверки |
| **Serving** | `ONNX Runtime`, `FastAPI`, `BentoML`, `KServe` | `llama.cpp` / `Ollama` / `vLLM`, `LiteLLM Gateway`, KV-cache, батчинг, стриминг |
| **Мониторинг** | Data Drift (`PSI`, `KS-тест` в `Evidently`), latency, RPS | Дрифт тематики запросов, расход токенов/сек, галлюцинации, трейсы в `Langfuse` |
| **Безопасность** | Вредоносный `pickle` (`modelscan`), отравление данных (Data Poisoning) | Prompt Injection, утечка PII (`Presidio` / `LLM Guard`), `OWASP LLM Top 10`, `MITRE ATLAS` |

---

## Ориентир по железу и выбору моделей (Intel 155H + 64 ГБ RAM, без NVIDIA)

Все стенды раздела спроектированы так, чтобы работать **локально на CPU**
(с опциональным ускорением на встроенной графике Intel Arc через Vulkan /
OpenVINO) без дискретной карты NVIDIA.

Главное узкое место при генерации текста на CPU и iGPU — не объём памяти,
а **пропускная способность оперативной памяти (Memory Bandwidth, ГБ/с)**.
На каждый сгенерированный токен процессор обязан прочитать из RAM все
активные веса модели:

| Роль в проекте | Рекомендуемая модель | Объём в RAM | Зачем и почему именно она |
| :--- | :--- | :--- | :--- |
| **Классификатор / Роутер** | `scikit-learn` / `DistilBERT` (`ONNX int8`) | ~50–250 МБ | Предсказание за 1–3 мс на CPU; отсекает мусор до вызова тяжёлой LLM |
| **Эмбеддинги (RAG)** | `bge-m3` или `multilingual-e5-base` (`ONNX int8`) | ~0.6–1.2 ГБ | Отличное качество русского и английского языка, быстрый CPU-инференс |
| **Реранкер (опц.)** | `bge-reranker-v2-m3` (`ONNX`) | ~1 ГБ | Переранжирует топ-20 найденных кусков документов в топ-5 самых точных |
| **Основная рабочая LLM** | `Qwen3-8B` (или `Llama-3.1-8B`), `GGUF Q4_K_M` | ~5.5 ГБ | Реалистичные 10–14 токенов/сек на 6 P-ядрах процессора |
| **Быстрая и умная (MoE)** | `Qwen3-30B-A3B`, `GGUF Q4_K_M` | ~18 ГБ | **Главный трюк для 64 ГБ RAM:** всего 30B параметров, но на каждый токен активны только 3B -> скорость как у 3B-модели, а ум как у 30B |
| **Модель для A/B-теста** | `Gemma-3-4B` или `12B` (`GGUF Q4_K_M`) | ~3–8 ГБ | Другая архитектура и иное поведение на русскоязычных документах |
| **Модель для LoRA SFT** | `Qwen2.5-0.5B` / `1.5B` или `SmolLM2` | ~1–3 ГБ | Учебное дообучение (`peft` + `trl`) на CPU за 10–20 минут |

### Бюджет оперативной памяти (при одновременном запуске стенда)

| Компонент стенда | Потребление RAM | Примечание |
| :--- | :--- | :--- |
| Кластер `k3d` + системные поды Kubernetes | ~3–4 ГБ | Одноузловой кластер в Docker |
| Локальная LLM (`8B Q4` или `30B-A3B MoE Q4`) | ~6 ГБ (или 18 ГБ) | Загружается через `mmap` из общего кэша |
| Эмбеддинги + ONNX-классификатор + OCR | ~2 ГБ | `onnxruntime` на CPU |
| `Qdrant` + `MLflow` + `PostgreSQL` + `SeaweedFS (S3)` | ~3–4 ГБ | Хранилища метаданных, векторов и файлов |
| `Prometheus` + `Grafana` + `Langfuse` | ~3–4 ГБ | Метрики и трейсинг запросов |
| ОС Linux + IDE + браузер | ~10+ ГБ | Свободный запас из 64 ГБ |

> **Важное правило для гибридных CPU (Intel Core Ultra 155H):**
> процессор имеет 6 быстрых P-ядер (потоки `0–11`), 8 медленных E-ядер и
> 2 LP-ядра. При запуске `llama.cpp` и `onnxruntime` всегда ограничивайте
> число потоков физическими P-ядрами (`--threads 6`, `taskset -c 0-11`
> или `cpuset: "0-11"`), иначе быстрые ядра будут простаивать на барьерах
> синхронизации, дожидаясь медленных E-ядер.

---

## Пререквизиты

- [1_linux_and_shell](../1_linux_and_shell/) — процессы, привязка к ядрам
  (`taskset`), работа с диском и памятью (`mmap`, Page Cache).
- [3_containers](../3_containers/) — сборка multi-stage `Dockerfile` и
  профили `Docker Compose`.
- [4_kubernetes](../4_kubernetes/) — `Deployment`, `Service`, `PVC`,
  `initContainers`, `Helm` (используются при деплое моделей в `k3d`).
- [6_cicd](../6_cicd/) — базовые пайплайны GitLab CI / GitHub Actions.
- [8_observability](../8_observability/) — сбор метрик в Prometheus и
  дашборды в Grafana.
- [10_devsecops](../10_devsecops/) — базовые принципы Supply Chain и
  сканирования артефактов.
- Python 3.12 и пакетный менеджер `uv` — соседний репозиторий
  [4_python_my_knowledgebase](../../4_python_my_knowledgebase/).

---

## Структура раздела (по порядку изучения)

1. **[00_environment](./00_environment/)** — подготовка рабочего места:
   фиксация Python 3.12 через `uv`, структура MLOps-репозитория, `.gitignore`
   для весов и личных документов, настройка P-ядер Intel 155H, общий том
   кэша моделей для Docker и `k3d`.
2. **[01_ml_lifecycle](./01_ml_lifecycle/)** — жизненный цикл модели:
   этапы от бизнес-задачи до переобучения, уровни зрелости MLOps (Google
   Levels 0 / 1 / 2, Microsoft), где зона ответственности DevOps/SRE,
   формирование «золотого датасета» (Golden Dataset).
3. **[02_huggingface_and_hubs](./02_huggingface_and_hubs/)** — экосистема
   Hugging Face и реестры моделей: устройство HF Hub, пиннинг по `revision`,
   `HF_HOME` и офлайн-режим; альтернативные хабы (`Ollama`, `ModelScope`,
   `NGC`, хранение весов в Docker-реестре через `ORAS / OCI Artifacts`);
   анатомия форматов (`pickle` RCE vs `safetensors`, `GGUF`, `ONNX`,
   `OpenVINO`); библиотеки `transformers`, `peft` (LoRA), `optimum`.
4. **[03_data_validation_and_dvc](./03_data_validation_and_dvc/)** —
   качество и версионирование данных: метрики качества данных, схемы
   `Pandera` и `Pydantic`, контракты `Great Expectations`, версионирование
   датасетов и бинарников через `DVC` поверх локального S3 (`SeaweedFS`).
5. **[04_experiment_tracking](./04_experiment_tracking/)** — трекинг
   экспериментов и реестр моделей: практика на `MLflow` + `SeaweedFS (S3)` +
   `PostgreSQL`, жизненный цикл версий в Model Registry; архитектурное
   сравнение с `ClearML` (`ClearML Server`, `ClearML Agent`, очереди).
6. **[05_training_pipelines](./05_training_pipelines/)** — оркестрация
   пайплайнов обучения: `Apache Airflow`, `Prefect`, `Kubeflow Pipelines`,
   `Argo Workflows`; практический пайплайн обучения классификатора и
   учебного LoRA-файнтюнинга (`peft` + `trl`) на CPU.
7. **[06_model_serving](./06_model_serving/)** — подача моделей в продакшне:
   паттерны Online / Batch / Streaming; классический инференс через
   `FastAPI + ONNX Runtime` на CPU и доставка весов в Pod через
   `initContainers`; LLM-сервинг (`llama.cpp`, `Ollama`, `vLLM`),
   квантование, KV-cache, единый шлюз **`LiteLLM AI Gateway`**, `KServe`.
8. **[07_cicd_for_ml](./07_cicd_for_ml/)** — CI/CD для ML и LLM:
   тестирование данных, инвариантов модели и отсутствия утечек в `pytest`;
   регрессионное тестирование промптов и RAG через `promptfoo`; Quality
   Gate перед промоушеном модели в продакшн.
9. **[08_feature_stores](./08_feature_stores/)** — хранилища признаков
   (теория и архитектура): проблема Training-Serving Skew, устройство
   `Feast`, Offline Store vs Online Store (`Redis`), когда Feature Store
   нужен, а когда избыточен.
10. **[09_model_monitoring](./09_model_monitoring/)** — мониторинг моделей
    и обратной связи: расчёт Data Drift и Concept Drift (`PSI`, `KS-тест`,
    `KL-дивергенция`) в `Evidently AI`, экспорт метрик в `Prometheus` и
    `Grafana`, автоматический триггер переобучения.
11. **[10_llmops_rag_and_eval](./10_llmops_rag_and_eval/)** — LLMOps,
    гибридный RAG и оценка качества: конвейер парсинга документов и OCR,
    векторный поиск в `Qdrant` с `bge-m3 (ONNX)`, реранкинг, версионирование
    промптов и трейсинг вызовов в `Langfuse`, метрики `RAGAS`.
12. **[11_ml_and_llm_security](./11_ml_and_llm_security/)** — безопасность
    ML/AI (AI DevSecOps): базы уязвимостей и угроз (`Huntr / Protect AI
    VulnDB`, `OWASP Top 10 for LLM & ML`, `MITRE ATLAS`, `AI Incident DB`);
    сканирование весов на закладки через `modelscan` и `fickling`;
    фаззинг и red-teaming LLM через `garak`; защита персональных данных
    (PII) через `Microsoft Presidio` и `LLM Guard`.
13. **[12_compute_and_gpu_infra](./12_compute_and_gpu_infra/)** —
    вычислительная и GPU-инфраструктура: арифметика памяти и пропускной
    способности, тюнинг CPU/iGPU/NPU (Intel Arc Vulkan / OpenVINO), а также
    архитектура промышленных NVIDIA GPU-кластеров в Kubernetes (`GPU
    Operator`, `MIG`, `Time-Slicing`, `DCGM-exporter`).
14. **[13_capstone_project](./13_capstone_project/)** — сквозной проект
    **«Личный защищённый архив документов и AI-ассистент»**: веб-сервис +
    S3 + табличный реестр с выгрузкой в Excel (`.xlsx`) + OCR для фото и
    сканов + авто-рубрикатор в `ONNX` (врачи / госорганы / заметки) +
    гибридный RAG по документам в `k3d` с полным мониторингом.

---

## Как проходить раздел

- **Базовый маршрут (по порядку):** `00` → `01` → `02` → `03` → `04` →
  `06` → `09` → `11` → `13`. Этого достаточно, чтобы руками собрать и
  защитить весь сквозной проект.
- **Оркестрация и углублённая теория:** `05` (пайплайны), `07` (CI/CD),
  `08` (Feature Stores), `10` (глубокий RAG и Langfuse), `12` (GPU в K8s).
- **Вопросы к собеседованию:** профильная папка
  [12_interview_questions_prep/11_mlops/](../12_interview_questions_prep/11_mlops/).

---

## Когда двигаться дальше

- Понимаете разницу между `pickle`, `safetensors`, `GGUF` и `ONNX`, умеете
  проверить чужую модель сканером `modelscan` и запустить её в `onnxruntime`.
- Можете поднять `MLflow` + `SeaweedFS (S3)`, залогировать обучение и
  доставить модель в Kubernetes-под через `initContainer`.
- Знаете, как устроен гибридный RAG поверх личных документов (OCR ->
  `Qdrant` -> локальная LLM за `LiteLLM`) и как отследить Data Drift в
  `Evidently` и трейсы в `Langfuse`.
