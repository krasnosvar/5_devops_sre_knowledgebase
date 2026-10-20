# 05. Оркестрация и пайплайны обучения (Airflow, Prefect, Kubeflow, LoRA)

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка по
> выбору оркестратора (`Airflow` vs `Prefect` vs `Kubeflow` vs `Argo`),
> пайплайну LoRA SFT и `PyTorchJob`.

## Зачем

Ручной запуск `python train.py` работает только один раз. В реальной
жизни переобучение модели — это цепочка зависимых шагов (DAG): забрать
новые документы из S3 → проверить схемы (`Pandera`) → обучить модель →
сравнить метрики на Golden Dataset с текущим `@champion` → сконвертировать
в `ONNX` / `GGUF` → переключить алиас в `MLflow`. Если любой шаг упал по
сети, оркестратор должен сделать `retry`, не пересчитывая заново уже
успешные тяжёлые шаги.

Эта глава разбирает промышленные оркестраторы ML-пайплайнов (`Airflow`,
`Prefect`, `Kubeflow Pipelines`, `Argo Workflows`), показывает, как
устроен учебный пайплайн дообучения LLM через **LoRA (`peft` + `trl`)** на
CPU, и даёт готовый пример пайплайна на `Prefect`.

## Пререквизиты

- [03_data_validation_and_dvc](../03_data_validation_and_dvc/) — валидация
  входных данных.
- [04_experiment_tracking](../04_experiment_tracking/) — логирование
  результатов в `MLflow` и промоушен в `Model Registry`.
- [4_kubernetes/02_workloads](../../4_kubernetes/02_workloads/) — `Job`,
  `CronJob` и поды в Kubernetes.

## Файлы

- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: матрица выбора
  оркестратора, правила передачи данных между шагами DAG, команды `Prefect`
  и LoRA.
- [01_theory/training_pipelines.md](./01_theory/training_pipelines.md) —
  архитектурное сравнение `Airflow`, `Prefect`, `Kubeflow Pipelines` и
  `Argo Workflows`; ловушка `XCom` в Airflow; пайплайн дообучения малой LLM
  через LoRA (`peft` + `trl`) на CPU; распределённое обучение в K8s
  (`PyTorchJob`); вопросы для собеседования.
- [02_examples/prefect_flow.py](./02_examples/prefect_flow.py) —
  исполняемый Python-first пайплайн обучения с ретраями, кэшированием
  шагов и проверкой порога качества (Quality Gate).

## Как проходить

1. Прочитать [01_theory/training_pipelines.md](./01_theory/training_pipelines.md).
2. Изучить код `02_examples/prefect_flow.py` и обратить внимание на
   декораторы `@task(retries=..., cache_key_fn=...)` и `@flow`.
3. Запустить пайплайн локально (`uv run --with prefect --with scikit-learn
   python3 02_examples/prefect_flow.py`).

## Когда двигаться дальше

- Можете обосновать выбор между `Airflow` (тяжёлый дата-инженерный стандарт),
  `Prefect` (лёгкий Python-first оркестратор) и `Kubeflow` / `Argo`
  (контейнерная изоляция каждого шага в K8s).
- Понимаете, почему между тасками оркестратора передаются только пути
  `s3://...`, а не сами датафреймы и веса моделей.
- Далее: [06_model_serving](../06_model_serving/).
