"""
Prefect pipeline для обучения модели
pip install prefect scikit-learn pandas mlflow

Запуск: python prefect_flow.py
или через Prefect Cloud: prefect deploy
"""

from prefect import flow, task, get_run_logger
from prefect.tasks import task_input_hash
from datetime import timedelta
import mlflow
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, roc_auc_score


@task(
    cache_key_fn=task_input_hash,
    cache_expiration=timedelta(hours=1),
    retries=2,
    retry_delay_seconds=30,
)
def load_data(data_path: str) -> pd.DataFrame:
    """Загрузить и проверить данные. Кэшируется 1 час."""
    logger = get_run_logger()
    logger.info(f"Loading data from {data_path}")

    # В реальности: pd.read_parquet("s3://bucket/data.parquet")
    from sklearn.datasets import load_breast_cancer
    data = load_breast_cancer()
    df = pd.DataFrame(data.data, columns=data.feature_names)
    df['target'] = data.target

    logger.info(f"Loaded {len(df)} rows, {len(df.columns)} columns")
    return df


@task
def preprocess(df: pd.DataFrame, test_size: float = 0.2) -> dict:
    """Разбить на train/test."""
    X = df.drop(columns=['target'])
    y = df['target']
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=test_size, random_state=42, stratify=y
    )
    return {
        "X_train": X_train, "X_test": X_test,
        "y_train": y_train, "y_test": y_test,
    }


@task(retries=1)
def train_model(data: dict, n_estimators: int = 100, max_depth: int = 10) -> dict:
    """Обучить модель и залогировать в MLflow."""
    logger = get_run_logger()

    mlflow.set_tracking_uri("http://localhost:5000")
    mlflow.set_experiment("cancer-classifier")

    with mlflow.start_run():
        params = {"n_estimators": n_estimators, "max_depth": max_depth}
        mlflow.log_params(params)

        clf = RandomForestClassifier(**params, random_state=42, n_jobs=-1)
        clf.fit(data["X_train"], data["y_train"])

        y_pred = clf.predict(data["X_test"])
        y_proba = clf.predict_proba(data["X_test"])[:, 1]

        metrics = {
            "accuracy": accuracy_score(data["y_test"], y_pred),
            "auc_roc": roc_auc_score(data["y_test"], y_proba),
        }
        mlflow.log_metrics(metrics)

        model_uri = mlflow.sklearn.log_model(clf, "model").model_uri
        logger.info(f"Model saved: {model_uri}, AUC={metrics['auc_roc']:.4f}")

        return {"metrics": metrics, "model_uri": model_uri}


@task
def evaluate_and_register(result: dict, threshold: float = 0.95) -> bool:
    """Зарегистрировать модель если метрика выше порога."""
    logger = get_run_logger()
    auc = result["metrics"]["auc_roc"]

    if auc >= threshold:
        mlflow.register_model(result["model_uri"], "CancerClassifier")
        logger.info(f"Model registered! AUC={auc:.4f} >= {threshold}")
        return True
    else:
        logger.warning(f"Model NOT registered. AUC={auc:.4f} < {threshold}")
        return False


@flow(name="cancer-classification-training", log_prints=True)
def training_pipeline(
    data_path: str = "local",
    n_estimators: int = 100,
    max_depth: int = 10,
    test_size: float = 0.2,
    quality_threshold: float = 0.95,
):
    """Полный pipeline обучения: загрузка → препроцессинг → обучение → регистрация."""
    df = load_data(data_path)
    data = preprocess(df, test_size=test_size)
    result = train_model(data, n_estimators=n_estimators, max_depth=max_depth)
    registered = evaluate_and_register(result, threshold=quality_threshold)

    if registered:
        print(f"Pipeline completed. Model registered with AUC={result['metrics']['auc_roc']:.4f}")
    else:
        print(f"Pipeline completed. Model quality below threshold.")


if __name__ == "__main__":
    training_pipeline(n_estimators=200, max_depth=8)
