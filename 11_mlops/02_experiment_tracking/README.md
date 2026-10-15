# 02. Experiment Tracking

## Зачем
Без трекинга экспериментов через месяц никто не скажет, на каких данных
и с какими параметрами обучена модель в продакшне. Тема разбирает MLflow
(runs, метрики, артефакты, Model Registry), DVC для версионирования
данных и W&B как альтернативу. На работе это обычно первая
MLOps-инфраструктура, которую просят поднять: tracking server + S3 для
артефактов.

## Пререквизиты
- [01_ml_lifecycle](../01_ml_lifecycle/) — где трекинг стоит в цикле
  модели.
- [3_containers/06_compose_patterns](../../3_containers/06_compose_patterns/)
  — стенд поднимается через Docker Compose (healthcheck,
  `depends_on` с условиями).
- Git: DVC работает поверх Git-репозитория; в этой базе Git не
  преподаётся, см.
  [01_git_essentials](../../../4_python_my_knowledgebase/0_tooling_and_workflow/01_git_essentials/)
  (соседний репозиторий). Достаточно `git init`, `git add`, `git commit`.

## Файлы
- [01_theory/experiment_tracking.md](./01_theory/experiment_tracking.md)
  — MLflow tracking и Model Registry, DVC и DVC pipeline, W&B.
- [02_examples/docker-compose.yml](./02_examples/docker-compose.yml) —
  стенд: MLflow tracking server + S3-хранилище артефактов (SeaweedFS,
  bucket `mlflow` создаётся при старте) + Jupyter.
- Отдельных упражнений и ответов нет: практика — запустить стенд и
  прогнать код MLflow из теории против него.

## Как проходить
1. Прочитать теорию до раздела про DVC.
2. Поднять стенд: `docker compose up -d` в `02_examples/`; MLflow UI —
   `http://localhost:5000`.
3. Логировать run с хоста: клиенту нужны `pip install mlflow boto3` и
   переменные `MLFLOW_TRACKING_URI=http://localhost:5000`,
   `MLFLOW_S3_ENDPOINT_URL=http://localhost:8333`,
   `AWS_ACCESS_KEY_ID=test`, `AWS_SECRET_ACCESS_KEY=test` — артефакты
   клиент пишет в S3 напрямую, а не через MLflow server.
4. Дочитать про DVC и W&B. Убрать стенд: `docker compose down -v`.

## Когда двигаться дальше
- Можете залогировать run с параметрами, метриками и моделью и найти его
  в UI.
- Можете объяснить, где лежат метаданные run, а где артефакты, и почему
  клиенту нужен доступ к S3.
- Можете объяснить, зачем DVC, если есть Git, и что хранится в `.dvc`
  файле.

Далее: [04_model_serving](../04_model_serving/) (рекомендуемый порядок
раздела), затем [03_training_pipelines](../03_training_pipelines/).
