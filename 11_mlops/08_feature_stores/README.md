# 08. Хранилища признаков (Feature Stores & Feast)

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка
> по Offline vs Online Store, `Point-in-Time Join (ASOF)` и командам
> `Feast`.

## Зачем

Когда Data Scientist считает признак «сумма расходов на медицину за
последние 90 дней» в SQL для обучения, а Backend-разработчик переписывает
эту логику на Python/Go для онлайн-сервиса, возникает **Training-Serving
Skew** (расхождение обучения и продакшена). Кроме того, при наивном
`JOIN` исторических таблиц легко заглянуть в будущее (**Time-Travel Data
Leakage**). Хранилище признаков (**Feature Store**, например **Feast**)
решает обе проблемы.

## Пререквизиты

- [03. Валидация данных и DVC](../03_data_validation_and_dvc/).
- [05. Пайплайны обучения](../05_training_pipelines/).

## Файлы

- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка по Feature Store и Feast.
- `01_theory/`
  - [feature_stores.md](./01_theory/feature_stores.md) — проблема
    Training-Serving Skew, архитектура Dual Store (Offline + Online),
    Point-in-Time Correctness (`ASOF JOIN`), Feast, когда Feature Store
    не нужен и 10 Q&A (без отдельной лабы: концепция разбирается
    теоретически и на коде Feast).

## Как проходить

1. Изучите [теорию](./01_theory/feature_stores.md) и разберите, как
   работает `get_historical_features` против `get_online_features`.
2. Проверьте себя по 10 вопросам в конце теоретического файла.

## Когда двигаться дальше

Вы готовы к разделу [09. Мониторинг моделей и Data Drift](../09_model_monitoring/),
если можете объяснить:
- чем `ASOF JOIN` отличается от обычного `LEFT JOIN` при сборке обучающей
  выборки;
- почему для онлайн-инференса с SLA `10 мс` нельзя читать признаки из
  Parquet/ClickHouse, а нужен Redis/DynamoDB (`Online Store`).
