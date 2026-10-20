# Отслеживание экспериментов и реестр моделей — шпаргалка

Подробности и архитектурный разбор — в
[experiment_tracking.md](./01_theory/experiment_tracking.md).
⚠️ — опасная команда или частая ловушка.

## Архитектура и запуск `MLflow Tracking Server`

| Компонент / Флаг | Что хранит / делает | Типичное значение в продакшне |
| :--- | :--- | :--- |
| `--backend-store-uri` | **Метаданные:** имена экспериментов, параметры, метрики, версии в Model Registry | `postgresql://user:pass@pg:5432/mlflow` (локально: `sqlite:///mlflow.db`) |
| `--default-artifact-root` | **Тяжёлые файлы:** веса моделей (`.onnx`, `.safetensors`), графики, слепки конфигов | `s3://mlflow/` (через `SeaweedFS` / `MinIO` / `AWS S3`) |
| `--serve-artifacts` | Проксирование загрузки артефактов через сам MLflow Server (чтобы клиентам не раздавать ключи S3) | Включать в корпоративных контурах |
| ⚠️ Ловушка: запуск `mlflow ui` без `--backend-store-uri` | Пишет в локальную папку `./mlruns` на файловой системе — Model Registry полноценно не работает | Всегда используйте `sqlite:///` или `postgresql://` для работы Model Registry |

## Ключевые вызовы `MLflow` Python SDK (версии 2.9+)

| Задача | Код на Python |
| :--- | :--- |
| Указать адрес сервера и имя эксперимента | `mlflow.set_tracking_uri("http://localhost:5000")` <br> `mlflow.set_experiment("personal-docs-router")` |
| Залогировать параметры, метрики и файл ONNX | `with mlflow.start_run():` <br> `    mlflow.log_params({"C": 1.0, "max_iter": 200})` <br> `    mlflow.log_metric("f1_macro", 0.96)` <br> `    mlflow.onnx.log_model(onnx_model, "model", registered_model_name="doc-router")` |
| Назначить версии модели прод-алиас `@champion` | `client = MlflowClient()` <br> `client.set_registered_model_alias("doc-router", "champion", version="3")` |
| Загрузить модель в сервисе по алиасу `@champion` | `model = mlflow.onnx.load_model("models:/doc-router@champion")` |
| ⚠️ Ловушка: использование `transition_model_version_stage("Production")` | Жёсткие стадии (`Staging`/`Production`) объявлены **deprecated** в MLflow 2.9+ — используйте **Model Aliases** (`@champion`, `@challenger`) |

## Сравнение платформ: `MLflow` vs `ClearML` vs `Weights & Biases`

| Критерий | `MLflow` (Open Source) | `ClearML` (Open Source / Enterprise) | `Weights & Biases` (SaaS / On-Prem) |
| :--- | :--- | :--- | :--- |
| **Философия** | Лёгкий модульный трекер + Model Registry (`UNIX-way`) | Монолитный комбайн «всё-в-одном» (трекер + оркестратор + агенты) | Лучший визуальный UI для глубокого обучения и LLM |
| **Как перехватывает данные** | Явные вызовы `mlflow.log_*` или `mlflow.autolog()` | Магический перехват `Task.init()` (парсит `argparse`, `git diff`, `stdout`, `matplotlib`) | Явный SDK `wandb.init()`, `wandb.log()` |
| **Управление воркерами** | Нет встроенного (делегируется в `Airflow` / `Kubernetes`) | Есть встроенный **`ClearML Agent`** и очереди задач (`queues`) на GPU/CPU нодах | Есть `W&B Launch` и `Sweeps` |
| **Сложность селф-хостинга** | 1 контейнер + БД + S3 (поднимается за 1 минуту) | Тяжёлый стек: `MongoDB` + `Elasticsearch` + `Redis` + 3 сервиса ClearML | Облачный SaaS (селф-хостинг платный) |

> Проверка: `docker compose -f 02_examples/docker-compose.yml config -q`; не проверено: интерактивный запуск `ClearML Server`.
