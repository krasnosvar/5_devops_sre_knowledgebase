# 06. Model Monitoring

## Зачем
Модель может отвечать быстро и без ошибок 5xx, но при этом всё хуже
предсказывать: изменились входные данные (data drift) или сама
зависимость, которую она выучила (concept drift). Обычный мониторинг
uptime/latency этого не видит. Тема показывает, как измерять drift (PSI,
KS-тест, Evidently), выводить его в Prometheus/Grafana, алертить и
решать, когда переобучать модель.

## Пререквизиты
- [01_ml_lifecycle](../01_ml_lifecycle/) — где мониторинг стоит в цикле
  модели.
- [8_observability/02_metrics_prometheus](../../8_observability/02_metrics_prometheus/)
  — метрики, PromQL, правила алертов; пример отдаёт drift как
  Prometheus-метрики.
- [8_observability/04_grafana](../../8_observability/04_grafana/) —
  дашборды для этих метрик.

## Файлы
- [01_theory/model_monitoring.md](./01_theory/model_monitoring.md) —
  data drift и методы его обнаружения, concept drift, мониторинг без
  ground truth, Grafana и алерты для ML, когда переобучать.
- [02_examples/drift_monitor.py](./02_examples/drift_monitor.py) —
  генерирует данные без дрейфа и с дрейфом, считает drift через
  Evidently и PSI, отдаёт метрики на `:8000/metrics`. Работает с
  `evidently<0.7`.
- [02_examples/docker-compose.yml](./02_examples/docker-compose.yml) —
  набросок стека Evidently + Prometheus + Grafana + MLflow. В текущем
  виде не запускается: файлов `prometheus.yml`, `evidently-config.yaml`,
  `grafana-datasources.yaml` рядом нет, образа `evidently/service` не
  существует. Используйте его как схему, а не как готовый стенд.
- Упражнений нет: практика — запуск `drift_monitor.py`.

## Как проходить
1. Прочитать теорию до раздела «Grafana для ML мониторинга».
2. Запустить пример и посмотреть, как меняются метрики, когда с 3-го окна
   начинается дрейф:

   ```bash
   pip install "evidently<0.7" scikit-learn pandas prometheus_client
   python drift_monitor.py
   ```

   Ожидаемо: окна 1–2 — `drift=0.000, action=ok`, окна 3–5 —
   `drift=0.750, ... action=retrain` и `DRIFT DETECTED`.
3. Дочитать теорию: алерты и критерии переобучения.

## Когда двигаться дальше
- Можете объяснить разницу data drift и concept drift и как ловить
  каждый.
- Можете посчитать PSI и объяснить пороги 0.1 и 0.25.
- Можете написать Prometheus-алерт на долю «уехавших» признаков.

Далее: [05_feature_stores](../05_feature_stores/), [07_llmops](../07_llmops/),
[08_gpu_infrastructure](../08_gpu_infrastructure/) — по необходимости.
