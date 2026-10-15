# 03. Training Pipelines

## Зачем
Обучение «руками в Jupyter» не повторить и не автоматизировать: нужен
оркестратор, который по расписанию или по событию (новые данные, drift)
прогонит загрузку данных → обучение → оценку → регистрацию модели, с
ретраями и кэшем. Тема сравнивает Kubeflow Pipelines, Airflow и Prefect
и показывает запуск распределённого обучения в Kubernetes.

## Пререквизиты
- [02_experiment_tracking](../02_experiment_tracking/) — пример пишет
  метрики и модель в MLflow; нужен поднятый стенд из этой темы.
- [4_kubernetes](../../4_kubernetes/) — для частей про Kubeflow Pipelines
  и Training Operator (PyTorchJob): Pod, Deployment, CRD
  ([11_operators_and_crds](../../4_kubernetes/11_operators_and_crds/)).
  Если Kubernetes ещё не освоен — эти части читаются как обзор, пример
  на Prefect работает без кластера.

## Файлы
- [01_theory/training_pipelines.md](./01_theory/training_pipelines.md) —
  зачем оркестратор, Kubeflow Pipelines, Airflow DAG, Prefect,
  distributed training (DDP, PyTorchJob), сравнение инструментов.
- [02_examples/prefect_flow.py](./02_examples/prefect_flow.py) — flow на
  Prefect: загрузка данных с кэшем и ретраями, обучение, логирование в
  MLflow, регистрация модели при превышении порога качества.
- Упражнений нет: Kubeflow и Training Operator требуют кластера с
  достаточными ресурсами (🖥 Tier 2), отдельная лаба пока не собрана.

## Как проходить
1. Прочитать теорию.
2. Поднять стенд MLflow из
   [02_experiment_tracking/02_examples](../02_experiment_tracking/02_examples/).
3. Запустить пример (переменные — те же, что для клиента MLflow в
   теме 02):

   ```bash
   pip install prefect scikit-learn pandas mlflow boto3
   export MLFLOW_S3_ENDPOINT_URL=http://localhost:8333
   export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test
   python prefect_flow.py
   ```

4. Найти run и зарегистрированную модель в MLflow UI.

## Когда двигаться дальше
- Можете объяснить, чем ML-пайплайн отличается от CI-пайплайна и зачем
  ему кэш шагов.
- Можете выбрать между Kubeflow, Airflow и Prefect для конкретной
  команды и обосновать выбор.
- Можете описать, что создаёт PyTorchJob в кластере (master/worker
  Pod'ы) и как они находят друг друга.

Далее: [06_model_monitoring](../06_model_monitoring/) (рекомендуемый
порядок раздела).
