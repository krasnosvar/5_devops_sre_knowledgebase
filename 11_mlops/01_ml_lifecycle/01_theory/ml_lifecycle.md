# ML Lifecycle — жизненный цикл модели

## Где DevOps-инженер пересекается с ML

ML-команда обычно отвечает за модель (данные, обучение, метрики).
DevOps/MLOps-инженер отвечает за инфраструктуру и автоматизацию:

| Этап | ML-команда | MLOps-инженер |
|------|-----------|---------------|
| Данные | Feature engineering, labeling | Data pipeline, хранилище, версионирование |
| Эксперименты | Обучение, подбор гиперпараметров | MLflow/W&B инфраструктура, вычисления |
| Оценка | Метрики модели | CI для моделей, A/B инфраструктура |
| Деплой | Конвертация модели | Serving инфраструктура, canary |
| Мониторинг | Метрики качества | Drift detection pipeline, алерты |
| Переобучение | Новые данные, обновление | Автоматический trigger, pipeline |

## Полный цикл

```
Бизнес-задача
    │
    ▼
Данные ──────────────────────────────────────────┐
    │  feature engineering, labeling, split       │
    ▼                                             │
Эксперименты (MLflow/W&B)                        │
    │  train → evaluate → iterate                 │
    ▼                                             │
Model Registry ──► версия, метаданные, метрики    │
    │                                             │
    ▼                                             │
CI для модели ──► unit тесты модели, нагрузочные  │
    │                                             │
    ▼                                             │
Staging деплой ──► smoke тесты, A/B               │
    │                                             │
    ▼                                             │
Production деплой ──► canary, feature flag        │
    │                                             │
    ▼                                             │
Мониторинг ──► data drift, model drift            │
    │                                             │
    └──── drift detected ──── trigger ────────────┘
                                    переобучение
```

## Артефакты в ML vs в DevOps

В обычном DevOps артефакт — бинарник или Docker образ.
В ML артефактов больше и они взаимосвязаны:

```
Код модели (Python, Go)
    +
Данные (версия датасета)        ← DVC, Delta Lake, Feature Store
    +
Обученные веса (модель файл)    ← MLflow Model Registry, S3
    +
Конфигурация (гиперпараметры)   ← MLflow, W&B
    +
Окружение (requirements.txt, Docker image)
    = Эксперимент (воспроизводимый)
```

**Reproducibility** — ключевое требование: дать другому человеку возможность
воспроизвести точно такую же модель. Нужно зафиксировать всё четыре.

## Разница мониторинга

```
Обычный сервис:        Latency, Error Rate, CPU/Memory
                              │
                       алерт → разбор → фикс

ML сервис:             Latency, Error Rate, CPU/Memory
                       + Data Drift (входные данные изменились)
                       + Model Drift / Concept Drift (мир изменился)
                       + Prediction Distribution (распределение предсказаний)
                              │
                       алерт → анализ данных → переобучение → деплой
```

**Data drift** — статистика входных данных изменилась относительно обучающей выборки.
Пример: модель обучалась на данных лета, деплоим зимой — другое поведение пользователей.

**Concept drift** — связь между признаками и целевой переменной изменилась.
Пример: модель оценки кредитного риска обучена до COVID — критерии риска изменились.

## MLflow — базовая инфраструктура

```python
import mlflow
import mlflow.sklearn

# experiment tracking
mlflow.set_experiment("fraud-detection-v2")

with mlflow.start_run():
    # логировать параметры
    mlflow.log_param("learning_rate", 0.01)
    mlflow.log_param("n_estimators", 100)

    # обучить
    model = train_model(X_train, y_train)

    # логировать метрики
    mlflow.log_metric("accuracy", accuracy)
    mlflow.log_metric("f1", f1_score)
    mlflow.log_metric("auc_roc", auc)

    # сохранить модель в registry
    mlflow.sklearn.log_model(
        model,
        "model",
        registered_model_name="FraudDetector"
    )
```

```bash
# запустить MLflow UI
mlflow ui --port 5000

# Docker Compose стенд
# docker-compose.yml в 03_exercises/01_mlflow_basics/
```

## DVC — версионирование данных и моделей

```bash
# инициализировать
dvc init
git add .dvc && git commit -m "Initialize DVC"

# добавить датасет под контроль DVC (хранится в S3, не в Git)
dvc add data/train.csv
git add data/train.csv.dvc .gitignore
git commit -m "Add training data"

# настроить remote storage
dvc remote add -d myremote s3://my-bucket/dvc
dvc push   # загрузить данные в S3

# другой человек получает данные
git clone ... && dvc pull

# сравнить версии данных
dvc diff HEAD~1

# pipeline как код (воспроизводимый)
dvc run -n train \
  -d data/train.csv -d src/train.py \
  -o models/model.pkl \
  python src/train.py
```
