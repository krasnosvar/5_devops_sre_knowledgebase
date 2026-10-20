# 06. Деплой и инференс моделей (Model Serving: ONNX, LLM & LiteLLM)

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка
> по ONNX Runtime на CPU, `initContainer` для весов в K8s, `llama.cpp`/
> `Ollama`/`vLLM`, `LiteLLM Proxy` и формулам расчета KV-cache.

## Зачем

Обученная модель бесполезна, пока она лежит в ноутбуке. Инженеру нужно
выбрать способ подачи модели (REST/gRPC онлайн, асинхронная очередь или
батч), не раздуть Docker-образ весами на 10 ГБ, ускорить классическую
модель в 3–5 раз на CPU через **ONNX Runtime**, поднять локальный
LLM-сервер (**Ollama / llama.cpp**) с ограничением по P-ядрам, закрыть
оба сервиса единым шлюзом **LiteLLM Proxy** и безопасно выкатить новую
версию через **Shadow / Canary / A/B**.

## Пререквизиты

- [02. Экосистема Hugging Face и реестры моделей](../02_huggingface_and_hubs/)
  (форматы `ONNX`, `GGUF`, `safetensors`).
- [04. Трекинг экспериментов и реестр моделей](../04_experiment_tracking/)
  (откуда `initContainer` скачивает `@champion`).
- [Kubernetes](../../4_kubernetes/) (Deployment, Probes, initContainers).

## Файлы

- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка по сервингу и KV-cache.
- `01_theory/`
  - [model_serving.md](./01_theory/model_serving.md) — паттерны подачи,
    ONNX Runtime, доставка весов в K8s, `llama.cpp`/`Ollama`/`vLLM`,
    LiteLLM Gateway, BentoML/Triton/KServe, A/B vs Shadow и 10 Q&A.
- `02_examples/`
  - [docker-compose.yml](./02_examples/docker-compose.yml) — локальный
    стенд инференса (`Ollama` с привязкой к P-ядрам + клиент).
- `03_exercises/`
  - [README.md](./03_exercises/README.md) — задания на запуск и замер
    латентности/токенов в секунду.
- `04_exercises_answers/`
  - [answers.md](./04_exercises_answers/answers.md) — разбор решений.

## Как проходить

1. Изучите [теорию](./01_theory/model_serving.md) (особенно разницу
   между вшиванием весов в образ и `initContainer`, а также математику
   KV-cache и работу PagedAttention).
2. Поднимите локальный стенд из `02_examples/docker-compose.yml` и
   выполните упражнения из [03_exercises/README.md](./03_exercises/README.md)
   (🐳 Tier 1, без NVIDIA GPU).

## Когда двигаться дальше

Вы готовы к разделу [07. CI/CD для ML и Quality Gates](../07_cicd_for_ml/),
если:
- можете объяснить, почему `startupProbe` критичен для пода, который
  грузит модель 45 секунд;
- умеете посчитать объем памяти под KV-cache для заданного `ctx-size`;
- понимаете разницу между `Shadow Deployment` и `A/B Testing`.
