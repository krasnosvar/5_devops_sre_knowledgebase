"""
Мониторинг data drift с помощью Evidently
pip install evidently scikit-learn pandas prometheus_client
"""

import pandas as pd
import numpy as np
from evidently.report import Report
from evidently.metrics import DatasetDriftMetric, DataDriftTable, ColumnDriftMetric
from evidently.test_suite import TestSuite
from evidently.tests import TestNumberOfDriftedColumns, TestShareOfDriftedColumns
from prometheus_client import Gauge, start_http_server
import time

# ── Prometheus метрики ────────────────────────────────────────────────────────
drift_gauge = Gauge('ml_data_drift_score', 'Overall data drift score')
drifted_features = Gauge('ml_drifted_features_count', 'Number of drifted features')
prediction_psi = Gauge('ml_prediction_psi', 'PSI score for prediction distribution')


def calculate_psi(reference: pd.Series, current: pd.Series, n_bins: int = 10) -> float:
    """Population Stability Index — 0.1+ = drift начинается, 0.25+ = значительный drift."""
    bins = np.percentile(reference, np.linspace(0, 100, n_bins + 1))
    bins[0] = -np.inf
    bins[-1] = np.inf

    ref_pct = np.histogram(reference, bins=bins)[0] / len(reference)
    cur_pct = np.histogram(current, bins=bins)[0] / len(current)

    ref_pct = np.where(ref_pct == 0, 1e-4, ref_pct)
    cur_pct = np.where(cur_pct == 0, 1e-4, cur_pct)

    return float(np.sum((cur_pct - ref_pct) * np.log(cur_pct / ref_pct)))


def run_drift_check(reference_df: pd.DataFrame, current_df: pd.DataFrame) -> dict:
    """Запустить полный drift check и вернуть результаты."""
    # Evidently report
    report = Report(metrics=[
        DatasetDriftMetric(),
        DataDriftTable(),
    ])
    report.run(reference_data=reference_df, current_data=current_df)
    result = report.as_dict()

    dataset_drift = result["metrics"][0]["result"]["dataset_drift"]
    n_drifted = result["metrics"][0]["result"]["number_of_drifted_columns"]
    drift_score = result["metrics"][0]["result"]["share_of_drifted_columns"]

    # Обновить Prometheus метрики
    drift_gauge.set(drift_score)
    drifted_features.set(n_drifted)

    if "prediction" in reference_df.columns:
        psi = calculate_psi(reference_df["prediction"], current_df["prediction"])
        prediction_psi.set(psi)

    return {
        "dataset_drift": dataset_drift,
        "drift_score": drift_score,
        "drifted_features": n_drifted,
        "action": "retrain" if drift_score > 0.5 else ("monitor" if drift_score > 0.2 else "ok")
    }


def generate_sample_data(n: int = 1000, drift: bool = False) -> pd.DataFrame:
    """Генерировать тестовые данные (с дрейфом или без)."""
    rng = np.random.RandomState(42 if not drift else 99)
    shift = 2.0 if drift else 0.0
    return pd.DataFrame({
        "feature_1": rng.normal(loc=0 + shift, scale=1, size=n),
        "feature_2": rng.normal(loc=5, scale=2, size=n),
        "feature_3": rng.choice(["A", "B", "C"], size=n,
                                p=[0.5, 0.3, 0.2] if not drift else [0.2, 0.6, 0.2]),
        "prediction": rng.beta(2, 5, size=n) if not drift else rng.beta(5, 2, size=n),
    })


if __name__ == "__main__":
    print("Starting drift monitoring service on :8000/metrics...")
    start_http_server(8000)

    reference = generate_sample_data(drift=False)
    print(f"Reference data: {len(reference)} rows")

    for window in range(1, 6):
        drift = window >= 3  # дрейф начинается с 3-го окна
        current = generate_sample_data(drift=drift)

        result = run_drift_check(reference, current)
        print(f"Window {window}: drift={result['drift_score']:.3f}, "
              f"features={result['drifted_features']}, "
              f"action={result['action']}")

        if result["dataset_drift"]:
            print(f"  ⚠️  DRIFT DETECTED! Action: {result['action']}")

        time.sleep(2)

    print("Check http://localhost:8000/metrics for Prometheus metrics")
