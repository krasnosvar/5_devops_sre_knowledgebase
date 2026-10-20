# 04. Отслеживание экспериментов и реестр моделей (MLflow и ClearML)

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка по
> архитектуре и API `MLflow`, алиасам `@champion`, сравнению с `ClearML`.

## Зачем

За время разработки модели проводят десятки запусков: меняют признаки,
алгоритмы, гиперпараметры, системные промпты и размеры чанков. Без
централизованного трекинга через неделю невозможно вспомнить, из какого
коммита Git и на каких данных получилась лучшая модель, а веса пересылаются
вручную.

Эта глава разбирает промышленный трекинг экспериментов и **Model Registry**:
- **На практике:** поднимаем стек **`MLflow` + `SeaweedFS (S3)`** в Docker
  Compose, логируем параметры, метрики и артефакты, управляем версиями и
  алиасами (`@champion` / `@challenger`) в реестре моделей.
- **В теории:** подробно разбираем архитектуру **`ClearML`** (`ClearML
  Server`, `Task.init`, `ClearML Agent` и очереди задач) и сравниваем,
  когда выбирать `MLflow`, когда `ClearML`, а когда `Weights & Biases`.

## Пререквизиты

- [00_environment](../00_environment/) — Docker Compose и Python 3.12.
- [01_ml_lifecycle](../01_ml_lifecycle/) — место экспериментов и реестра в
  жизненном цикле.
- [03_data_validation_and_dvc](../03_data_validation_and_dvc/) — связь
  запуска модели с хэшем датасета.

## Файлы

- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: запуск `mlflow server`,
  Python SDK, алиасы реестра `@champion`, сравнение `MLflow` vs `ClearML`.
- [01_theory/experiment_tracking.md](./01_theory/experiment_tracking.md) —
  разделение Backend Store и Artifact Store в `MLflow`, Model Registry и
  переход от Stages к Model Aliases, архитектура `ClearML` и `ClearML
  Agent`, трекинг LLM/RAG-экспериментов, вопросы для собеседования.
- [02_examples/docker-compose.yml](./02_examples/docker-compose.yml) —
  готовый локальный стенд: `SeaweedFS (S3)` + `MLflow Tracking Server` +
  `Jupyter` (🐳 Tier 1).

## Как проходить

1. Прочитать [01_theory/experiment_tracking.md](./01_theory/experiment_tracking.md).
2. Поднять стенд `docker compose -f 02_examples/docker-compose.yml up -d`.
3. Открыть UI `MLflow` на `http://localhost:5000`, залогировать тестовый
   запуск и проверить, что артефакты легли в S3-бакет `mlflow`.
4. Остановить стенд (`docker compose down`).

## Когда двигаться дальше

- Понимаете, почему `MLflow Server` сам не хранит гигабайтные файлы весов в
  SQL-базе, а разделяет **Backend Store** (метаданные) и **Artifact Store**
  (объектное хранилище S3).
- Можете объяснить разницу между подходом `MLflow` (явный SDK-трекинг) и
  `ClearML` (`Task.init` + встроенный оркестратор очередей `ClearML Agent`).
- Далее: [05_training_pipelines](../05_training_pipelines/).
