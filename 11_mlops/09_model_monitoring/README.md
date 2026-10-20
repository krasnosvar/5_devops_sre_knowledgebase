# 09. Мониторинг моделей и Data Drift (Evidently, PSI & Prometheus)

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка
> по типам дрейфа (Covariate, Prior/Label, Concept), порогам `PSI` /
> `KS-test`, `Evidently` и алертам Prometheus.

## Зачем

Обычный микросервис при поломке начинает пятисотить (`HTTP 500`) или
расти по латентности. ML-модель деградирует **молча**: сервис отвечает
`200 OK` за `3 мс`, CPU и память в норме, но после смены шаблона
налоговых уведомлений ФНС или появления новых бланков лаборатории модель
начинает выдавать мусорные предсказания.

Раздел учит детектировать **Data Drift**, **Prediction Drift** и
**Concept Drift** с помощью **PSI**, критерия **Колмогорова-Смирнова**,
**Evidently** и экспортировать метрики в **Prometheus / Grafana**.

## Пререквизиты

- [Observability (Prometheus / Grafana)](../../8_observability/).
- [06. Деплой и инференс моделей](../06_model_serving/).

## Файлы

- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка по метрикам дрейфа и
  порогам `PSI`.
- `01_theory/`
  - [model_monitoring.md](./01_theory/model_monitoring.md) — 4 слоя
    мониторинга ML, математика `PSI` и `KS-test`, Covariate vs Concept
    Drift, мониторинг без Ground Truth, `Evidently` + `Prometheus` и
    10 Q&A.
- `02_examples/`
  - [drift_monitor.py](./02_examples/drift_monitor.py) — расчет `PSI`
    и `Evidently` отчетов с экспортом метрик в Prometheus.
  - [docker-compose.yml](./02_examples/docker-compose.yml) — стенд
    Prometheus + Grafana для сбора метрик дрейфа.

## Как проходить

1. Изучите [теорию](./01_theory/model_monitoring.md).
2. Разберите код [02_examples/drift_monitor.py](./02_examples/drift_monitor.py)
   и правила алертинга Prometheus.

## Когда двигаться дальше

Вы готовы к разделу [10. LLMOps: RAG, векторные БД, трейсинг и оценка](../10_llmops_rag_and_eval/),
если:
- знаете пороговые значения `PSI` (`< 0.1`, `0.1–0.25`, `> 0.25`);
- понимаете, почему при отсутствии быстрой разметки (`Delayed Ground
  Truth`) главным сигналом служит **Prediction Drift** и доля низкой
  уверенности модели (`low confidence rate`).
