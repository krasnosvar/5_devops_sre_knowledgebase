# Training Pipelines

## Зачем нужен оркестратор для ML

Обучение модели — не одна команда, а DAG задач:
```
raw data → validate → preprocess → feature_engineering → train → evaluate → register
```

Без оркестратора: bash скрипт, нет retry, нет параллелизма, нет UI.
С оркестратором: визуальный DAG, параллельные шаги, автоматический retry, версионирование.

## Kubeflow Pipelines — k8s-native

```python
# pipeline.py — определить pipeline через Python SDK
from kfp import dsl, compiler
from kfp.kubernetes import use_config_map_as_env

@dsl.component(
    base_image="python:3.12-slim",
    packages_to_install=["pandas", "scikit-learn", "mlflow"]
)
def preprocess(
    input_path: str,
    output_path: dsl.Output[dsl.Dataset],
    test_size: float = 0.2
):
    import pandas as pd
    from sklearn.model_selection import train_test_split

    df = pd.read_parquet(input_path)
    train, test = train_test_split(df, test_size=test_size, random_state=42)
    train.to_parquet(output_path.path + "/train.parquet")
    test.to_parquet(output_path.path + "/test.parquet")


@dsl.component(
    base_image="python:3.12-slim",
    packages_to_install=["xgboost", "mlflow", "scikit-learn"]
)
def train(
    data_path: dsl.Input[dsl.Dataset],
    model: dsl.Output[dsl.Model],
    learning_rate: float = 0.01,
    n_estimators: int = 100,
) -> float:
    import mlflow
    import xgboost as xgb

    mlflow.set_tracking_uri("http://mlflow:5000")
    with mlflow.start_run():
        mlflow.log_params({"lr": learning_rate, "n": n_estimators})
        clf = xgb.XGBClassifier(learning_rate=learning_rate, n_estimators=n_estimators)
        clf.fit(X_train, y_train)
        auc = roc_auc_score(y_test, clf.predict_proba(X_test)[:, 1])
        mlflow.log_metric("auc", auc)
        mlflow.xgboost.log_model(clf, "model")
    return auc


@dsl.pipeline(name="fraud-detection-training")
def training_pipeline(
    input_path: str = "s3://my-bucket/data/transactions.parquet",
    learning_rate: float = 0.01,
):
    preprocess_task = preprocess(input_path=input_path)

    train_task = train(
        data_path=preprocess_task.outputs["output_path"],
        learning_rate=learning_rate,
    )
    train_task.set_cpu_request("2").set_memory_request("4G")
    train_task.set_gpu_limit("1")  # запросить GPU


# скомпилировать и деплоить
compiler.Compiler().compile(training_pipeline, "pipeline.yaml")
```

```bash
# деплоить в Kubeflow
kfp pipeline upload --pipeline-name fraud-detection pipeline.yaml

# запустить
kfp run submit --experiment-name fraud-v3 \
  --pipeline-name fraud-detection \
  --argument learning_rate=0.05
```

## Apache Airflow — общий DAG оркестратор

```python
# dags/fraud_training.py
from airflow.decorators import dag, task
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator
from datetime import datetime

@dag(schedule="@weekly", start_date=datetime(2024, 1, 1), catchup=False)
def fraud_training_pipeline():

    @task
    def check_data_freshness() -> bool:
        """Проверить что новые данные доступны"""
        from minio import Minio
        client = Minio("minio:9000", access_key="...", secret_key="...")
        # проверить дату последнего файла
        return True

    preprocess = KubernetesPodOperator(
        task_id="preprocess",
        name="preprocess",
        namespace="ml",
        image="my-registry/ml-preprocess:latest",
        arguments=["--input", "s3://data/raw/", "--output", "s3://data/processed/"],
        resources={"request_cpu": "2", "request_memory": "4G"},
    )

    train = KubernetesPodOperator(
        task_id="train",
        name="train",
        namespace="ml",
        image="my-registry/ml-train:latest",
        arguments=["--data", "s3://data/processed/", "--mlflow-uri", "http://mlflow:5000"],
        resources={"request_cpu": "4", "request_memory": "16G", "limit_gpu": "1"},
    )

    @task
    def check_model_quality(auc: float) -> bool:
        if auc < 0.95:
            raise ValueError(f"Model AUC {auc} below threshold 0.95")
        return True

    register = KubernetesPodOperator(
        task_id="register",
        name="register-model",
        namespace="ml",
        image="my-registry/ml-register:latest",
    )

    freshness = check_data_freshness()
    freshness >> preprocess >> train >> register


dag = fraud_training_pipeline()
```

## Prefect — Python-first оркестратор

```python
from prefect import flow, task
from prefect.tasks import task_input_hash
from datetime import timedelta

@task(cache_key_fn=task_input_hash, cache_expiration=timedelta(hours=1))
def preprocess(data_path: str) -> str:
    """Кэшировать результат — не пересчитывать если данные не менялись"""
    ...
    return processed_path

@task(retries=3, retry_delay_seconds=60)
def train_model(data_path: str, learning_rate: float = 0.01) -> dict:
    """Автоматический retry при сбое"""
    ...
    return {"auc": 0.97, "model_uri": "s3://..."}

@task
def register_if_good(metrics: dict, threshold: float = 0.95):
    if metrics["auc"] >= threshold:
        mlflow.register_model(metrics["model_uri"], "FraudDetector")

@flow(name="fraud-training", log_prints=True)
def training_flow(
    data_path: str = "s3://data/transactions.parquet",
    learning_rate: float = 0.01
):
    processed = preprocess(data_path)
    metrics = train_model(processed, learning_rate)
    register_if_good(metrics)

# запустить
training_flow(learning_rate=0.05)

# scheduled deployment
from prefect.deployments import Deployment
Deployment.build_from_flow(
    flow=training_flow,
    name="weekly-training",
    schedule=CronSchedule(cron="0 6 * * 1"),
    work_pool_name="kubernetes-pool"
)
```

## Distributed Training — несколько GPU

```python
# PyTorch DDP (DistributedDataParallel)
import torch.distributed as dist
from torch.nn.parallel import DistributedDataParallel as DDP

# Kubeflow Training Operator — запуск распределённого обучения в k8s
```

```yaml
# PyTorchJob — 1 master + 3 workers
apiVersion: kubeflow.org/v1
kind: PyTorchJob
metadata:
  name: fraud-distributed-training
spec:
  pytorchReplicaSpecs:
    Master:
      replicas: 1
      template:
        spec:
          containers:
            - name: pytorch
              image: my-registry/training:latest
              args: ["--epochs", "100", "--batch-size", "512"]
              resources:
                limits:
                  nvidia.com/gpu: 1
    Worker:
      replicas: 3
      template:
        spec:
          containers:
            - name: pytorch
              image: my-registry/training:latest
              resources:
                limits:
                  nvidia.com/gpu: 1
```

## Сравнение инструментов

| | Kubeflow | Airflow | Prefect |
|--|---------|---------|---------|
| Платформа | Kubernetes-native | Любая | Любая |
| Язык | Python SDK → YAML | Python DAG | Python |
| UI | Встроен в k8s | Полноценный web UI | Cloud UI + self-hosted |
| Кривая обучения | Высокая | Средняя | Низкая |
| Лучше для | ML teams с k8s | Общий data engineering | Простые ML pipelines |
