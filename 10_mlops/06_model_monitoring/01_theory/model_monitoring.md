# Model Monitoring

## Чем отличается от обычного мониторинга

Обычный сервис: мониторим uptime, latency, error rate.
ML сервис: добавляется мониторинг качества модели — она может деградировать
«молча» (latency ок, ошибок нет, но предсказания плохие).

```
Инфраструктурные метрики (как обычно)
    + Метрики качества данных (drift, nulls, outliers)
    + Метрики качества модели (accuracy, распределение предсказаний)
    + Бизнес-метрики (click-through rate, conversion — ground truth с задержкой)
```

## Data Drift — входные данные изменились

**Covariate shift**: распределение признаков X изменилось.
Пример: модель обучена на летних данных, деплой зимой — другие покупательские паттерны.

**Label shift**: распределение целевого признака Y изменилось.
Пример: класс мошеннических транзакций стал в 3 раза больше.

### Методы обнаружения

```python
from evidently.metrics import (
    DatasetDriftMetric,
    DataDriftTable,
    ColumnDriftMetric
)
from evidently.report import Report

# сравнить reference (обучающий) и current (production) датасеты
report = Report(metrics=[
    DatasetDriftMetric(),          # общий drift dataset
    DataDriftTable(),              # drift по каждому признаку
    ColumnDriftMetric(column_name="age"),
    ColumnDriftMetric(column_name="transaction_amount"),
])

report.run(reference_data=train_df, current_data=production_df)
report.save_html("drift_report.html")

# получить результаты программно
result = report.as_dict()
if result["metrics"][0]["result"]["dataset_drift"]:
    print("DRIFT DETECTED! Trigger retraining pipeline.")
```

**Статистические тесты:**
- **PSI (Population Stability Index)**: < 0.1 — нет drift, 0.1–0.25 — умеренный, > 0.25 — значительный
- **KL Divergence**: асимметричная мера расхождения распределений
- **KS test (Kolmogorov-Smirnov)**: для непрерывных признаков
- **Chi-squared**: для категориальных признаков
- **Jensen-Shannon Divergence**: симметричная версия KL

```python
from scipy.stats import ks_2samp, chi2_contingency
import numpy as np

def check_drift(reference: np.ndarray, current: np.ndarray,
                threshold: float = 0.05) -> bool:
    """KS test для непрерывного признака"""
    stat, p_value = ks_2samp(reference, current)
    return p_value < threshold   # True = drift detected
```

## Concept Drift — мир изменился

Связь между X и Y изменилась, даже если X не изменился.
Пример: кредитная модель обучена до COVID — критерии риска изменились.

Обнаружить сложнее: нужен ground truth (реальный исход).
Ground truth часто доступен с задержкой: мошенничество подтверждается через недели.

```python
# Мониторинг метрик модели при наличии ground truth
from evidently.metrics import ClassificationQualityMetric

report = Report(metrics=[
    ClassificationQualityMetric(),
])
report.run(
    reference_data=past_predictions_with_labels,
    current_data=recent_predictions_with_labels
)
```

## Мониторинг предсказаний без ground truth

```python
# Распределение предсказаний — изменилось ли?
import pandas as pd

current_predictions = model.predict_proba(X_current)[:, 1]
reference_predictions = model.predict_proba(X_reference)[:, 1]

# PSI для предсказаний
def psi(reference, current, n_bins=10):
    bins = np.percentile(reference, np.linspace(0, 100, n_bins + 1))
    ref_counts = np.histogram(reference, bins=bins)[0] / len(reference)
    cur_counts = np.histogram(current, bins=bins)[0] / len(current)
    ref_counts = np.where(ref_counts == 0, 0.0001, ref_counts)
    cur_counts = np.where(cur_counts == 0, 0.0001, cur_counts)
    return np.sum((cur_counts - ref_counts) * np.log(cur_counts / ref_counts))

score = psi(reference_predictions, current_predictions)
print(f"PSI: {score:.4f} — {'drift' if score > 0.25 else 'ok'}")
```

## Grafana для ML мониторинга

```yaml
# docker-compose: MLflow + Evidently + Prometheus + Grafana
services:
  mlflow:
    image: ghcr.io/mlflow/mlflow:latest
    ports: ["5000:5000"]

  evidently-service:
    image: evidently/service:latest
    ports: ["8085:8085"]
    volumes:
      - ./evidently_config.yaml:/app/config.yaml

  prometheus:
    image: prom/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    # scrape evidently metrics: drift scores, prediction distributions
```

```yaml
# evidently_config.yaml
min_reference_size: 1000
use_reference: true
moving_reference: false
window_size: 100  # размер окна для сравнения

monitors:
  - data_drift
  - cat_target_drift
  - num_target_drift
  - regression_performance
  - classification_performance
```

## Alerting для ML

```yaml
# Prometheus alert для drift
groups:
  - name: ml.rules
    rules:
      - alert: DataDriftDetected
        expr: evidently_data_drift_share > 0.5
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Data drift detected for {{ $labels.model }}"
          description: "{{ $value | humanizePercentage }} features drifted"

      - alert: PredictionDistributionShift
        expr: ml_prediction_psi > 0.25
        for: 30m
        labels:
          severity: critical
        annotations:
          summary: "Prediction distribution shifted for {{ $labels.model }}"
          description: "PSI={{ $value:.3f }}, threshold=0.25. Trigger retraining."

      - alert: ModelAccuracyDrop
        expr: ml_model_accuracy_1d < 0.90
        for: 1h
        labels:
          severity: critical
```

## Когда переобучать

| Сигнал | Действие |
|--------|---------|
| Data drift PSI > 0.25 | Немедленно переобучить |
| Data drift PSI 0.1–0.25 | Запланировать переобучение |
| Accuracy drop > 5% (при наличии GT) | Немедленно переобучить |
| Prediction PSI > 0.25 | Расследовать + переобучить |
| Плановое расписание | Регулярно (еженедельно/ежемесячно) |

```python
# Автоматический trigger переобучения через MLflow + Airflow/Prefect
from airflow.decorators import dag, task
from airflow.sensors.python import PythonSensor

@dag(schedule_interval="@daily")
def drift_monitoring():

    @task
    def check_drift():
        # вычислить PSI для текущих данных
        psi_score = calculate_psi(reference_data, current_data)
        return psi_score > 0.25

    @task
    def trigger_retraining(should_retrain: bool):
        if should_retrain:
            mlflow.run("https://github.com/org/ml-project",
                      entry_point="train",
                      parameters={"data_path": "s3://bucket/current/"})

    should_retrain = check_drift()
    trigger_retraining(should_retrain)
```
