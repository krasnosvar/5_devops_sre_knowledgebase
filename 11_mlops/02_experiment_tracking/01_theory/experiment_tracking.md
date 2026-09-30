# Experiment Tracking

## Зачем нужен трекинг экспериментов

ML эксперимент сложнее git commit: помимо кода важны данные, гиперпараметры,
метрики, артефакты (модели, графики). Без трекинга через неделю не вспомнишь
какая конфигурация дала лучший результат.

**Что нужно записывать:**
- Параметры (learning_rate, batch_size, architecture)
- Метрики (accuracy, loss, F1, AUC) — в динамике по эпохам
- Артефакты (веса модели, confusion matrix, feature importance)
- Окружение (версии библиотек, Python, CUDA)
- Данные (какой датасет, какой split, какая версия)

## MLflow — основной инструмент

```python
import mlflow
import mlflow.sklearn
import mlflow.pytorch
from mlflow.models import infer_signature

# настроить сервер (или использовать локальный)
mlflow.set_tracking_uri("http://localhost:5000")
mlflow.set_experiment("fraud-detection-v3")

with mlflow.start_run(run_name="xgboost-baseline") as run:
    # параметры
    params = {
        "learning_rate": 0.01,
        "max_depth": 6,
        "n_estimators": 500,
        "subsample": 0.8,
    }
    mlflow.log_params(params)

    # обучение
    model = XGBClassifier(**params)
    model.fit(X_train, y_train,
              eval_set=[(X_val, y_val)],
              callbacks=[mlflow.xgboost.autolog()])  # автологирование

    # метрики финальные
    y_pred = model.predict(X_test)
    mlflow.log_metrics({
        "accuracy": accuracy_score(y_test, y_pred),
        "f1": f1_score(y_test, y_pred),
        "auc_roc": roc_auc_score(y_test, model.predict_proba(X_test)[:, 1]),
        "precision": precision_score(y_test, y_pred),
        "recall": recall_score(y_test, y_pred),
    })

    # артефакты
    mlflow.log_figure(plot_confusion_matrix(y_test, y_pred), "confusion_matrix.png")
    mlflow.log_figure(plot_feature_importance(model), "feature_importance.png")

    # сохранить модель в registry
    signature = infer_signature(X_train, y_pred)
    mlflow.xgboost.log_model(
        model,
        "model",
        signature=signature,
        registered_model_name="FraudDetector",
        input_example=X_train[:5]
    )

    print(f"Run ID: {run.info.run_id}")
    print(f"Model URI: runs:/{run.info.run_id}/model")
```

## MLflow Model Registry

```python
from mlflow.tracking import MlflowClient

client = MlflowClient()

# перевести версию в Staging
client.transition_model_version_stage(
    name="FraudDetector",
    version=5,
    stage="Staging",
    archive_existing_versions=False
)

# загрузить лучшую модель из Production
model = mlflow.xgboost.load_model("models:/FraudDetector/Production")

# поиск лучшего run
best_run = mlflow.search_runs(
    experiment_ids=["1"],
    filter_string="metrics.auc_roc > 0.95 AND params.learning_rate < 0.05",
    order_by=["metrics.auc_roc DESC"],
    max_results=1
).iloc[0]

print(f"Best run: {best_run.run_id}, AUC: {best_run['metrics.auc_roc']:.4f}")
```

## DVC — версионирование данных

```bash
# инициализация
git init && dvc init
git add .dvc && git commit -m "init DVC"

# добавить большой датасет
dvc add data/transactions.parquet
git add data/transactions.parquet.dvc .gitignore
git commit -m "Add transaction dataset v1"

# настроить remote storage
dvc remote add -d s3remote s3://my-bucket/dvc-store
dvc remote modify s3remote region eu-central-1
git add .dvc/config && git commit -m "Configure S3 remote"

# загрузить
dvc push

# другой инженер
git clone https://github.com/org/ml-project
dvc pull                    # скачает данные из S3

# версионирование: обновить датасет
# (изменить data/transactions.parquet)
dvc add data/transactions.parquet
git add data/transactions.parquet.dvc
git commit -m "Add Q4 2024 transactions"
dvc push

# вернуться к предыдущей версии
git checkout HEAD~1 -- data/transactions.parquet.dvc
dvc checkout
```

## DVC Pipeline — воспроизводимый workflow

```yaml
# dvc.yaml
stages:
  preprocess:
    cmd: python src/preprocess.py
    deps:
      - data/raw/transactions.parquet
      - src/preprocess.py
    params:
      - params.yaml:
        - preprocess.test_size
        - preprocess.random_state
    outs:
      - data/processed/train.parquet
      - data/processed/test.parquet

  train:
    cmd: python src/train.py
    deps:
      - data/processed/train.parquet
      - src/train.py
    params:
      - params.yaml:
        - model.learning_rate
        - model.n_estimators
    outs:
      - models/model.pkl
    metrics:
      - metrics.json:
          cache: false
```

```bash
dvc repro              # запустить pipeline (только изменённые этапы)
dvc dag                # визуализация зависимостей
dvc metrics show       # показать метрики
dvc params diff HEAD~1 # сравнить параметры с предыдущим commit
```

## Weights & Biases (W&B) — альтернатива MLflow

```python
import wandb

run = wandb.init(
    project="fraud-detection",
    name="xgboost-v3",
    config={
        "learning_rate": 0.01,
        "max_depth": 6,
        "dataset_version": "v3.2"
    }
)

# логирование метрик по эпохам
for epoch in range(100):
    metrics = train_epoch(model, data)
    wandb.log({
        "train/loss": metrics["loss"],
        "train/auc": metrics["auc"],
        "epoch": epoch
    })

# артефакты
artifact = wandb.Artifact("model", type="model")
artifact.add_file("models/model.pkl")
run.log_artifact(artifact)

wandb.finish()
```

**W&B vs MLflow:**
- W&B: лучший UI, богатые visualizations, встроенный hyperparameter sweep, SaaS
- MLflow: open-source, self-hosted, проще интеграция с Databricks/Spark
