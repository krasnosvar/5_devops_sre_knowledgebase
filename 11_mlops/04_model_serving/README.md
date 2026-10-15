# 04. Model Serving

## Зачем
Обученная модель приносит пользу только за API: с предсказуемой
latency, батчингом, метриками и безопасным выкатом новых версий. Тема
разбирает serving классических моделей (BentoML, KServe, Triton) и LLM
(vLLM), а также A/B и canary для моделей. На работе это та часть MLOps,
которая ближе всего к обычной эксплуатации сервисов.

## Пререквизиты
- [02_experiment_tracking](../02_experiment_tracking/) — откуда берётся
  версия модели (Model Registry).
- [3_containers](../../3_containers/) — образы, Docker Compose.
- nginx как reverse proxy (`upstream`, `proxy_pass`) — нужен в
  упражнении 03; достаточно уровня конфигов из
  [0_lab_setup/01_docker_compose](../../0_lab_setup/01_docker_compose/).

> **Забегание вперёд.** Части теории про KServe и Istio используют
> Kubernetes, который подробно разбирается в
> [4_kubernetes](../../4_kubernetes/). Для этой темы достаточно: что
> такое Deployment, Service и CRD. Если Kubernetes ещё не освоен — эти
> части можно пропустить, упражнения работают в Docker.

## Файлы
- [01_theory/model_serving.md](./01_theory/model_serving.md) — паттерны
  serving, vLLM (только GPU) и его параметры, BentoML 1.2+, KServe,
  Triton, A/B через Istio, ключевые метрики.
- [02_examples/docker-compose.yml](./02_examples/docker-compose.yml) —
  vLLM + MLflow + S3-хранилище (SeaweedFS). Сервис `vllm` требует NVIDIA
  GPU; без GPU запускаются только `s3` и `mlflow`.
- [03_exercises/README.md](./03_exercises/README.md) — 3 упражнения:
  LLM на CPU через Ollama, упаковка модели в BentoML, A/B 80/20 через
  nginx; 🐳 Tier 1, без GPU.
- [04_exercises_answers/answers.md](./04_exercises_answers/answers.md) —
  ответы с ожидаемым выводом;
  [04_exercises_answers/ab_test/](./04_exercises_answers/ab_test/) —
  готовый стенд A/B (compose, nginx.conf, заглушка модели).

## Как проходить
1. Теория. Раздел про vLLM читать, даже если GPU нет: API у Ollama тот
   же.
2. Упражнения 01 → 02 → 03 по порядку, сверка с ответами.
3. Если есть NVIDIA GPU — поднять `02_examples/docker-compose.yml`
   целиком и повторить упражнение 01 против vLLM на порту 8000.

## Когда двигаться дальше
- Можете поднять LLM с OpenAI-совместимым API и объяснить, почему для
  vLLM нужна GPU, а для Ollama/llama.cpp — нет.
- Можете упаковать sklearn-модель в BentoML-сервис и вызвать его
  `curl`'ом.
- Можете настроить разделение трафика между версиями модели и объяснить,
  как выбор ключа `split_clients` влияет на распределение.

Далее: [03_training_pipelines](../03_training_pipelines/) (рекомендуемый
порядок раздела).
