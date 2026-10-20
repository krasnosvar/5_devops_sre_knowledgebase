# 03. Качество, валидация и версионирование данных (Pandera, GX, DVC)

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка по
> метрикам качества данных, схемам `Pandera`, контрактам `Great Expectations`
> и командам `DVC`.

## Зачем

Принцип «Garbage In — Garbage Out» в MLOps и LLMOps проявляется жёстче,
чем в обычной разработке: если в обучающую выборку или в базу знаний RAG
попали битые PDF после пустого OCR, дубликаты справок, перепутанные
категории или пропущенные значения (`NaN`), обучение молча завершится с
кодом возврата `0`, но модель в продакшне начнёт выдавать бред.

Вторая проблема — **воспроизводимость данных**: код версионируется в Git,
но положить в Git гигабайты датасетов и сканов документов нельзя.

Эта глава закрывает обе задачи:
1. Автоматический контроль качества данных (**Data Contracts**) на входе в
   пайплайн с помощью `Pandera`, `Pydantic` и `Great Expectations`.
2. Версионирование датасетов и воспроизводимые DAG-пайплайны в **`DVC`
   (Data Version Control)** поверх локального S3-хранилища (`SeaweedFS`).

## Пререквизиты

- [00_environment](../00_environment/) — настроенный Python 3.12 и `uv`.
- [01_ml_lifecycle](../01_ml_lifecycle/) — концепция «Золотого набора»
  (Golden Dataset).
- [02_huggingface_and_hubs](../02_huggingface_and_hubs/) — понимание
  контент-адресуемого кэша по хэшам (в `DVC` используется тот же принцип).

## Файлы

- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: `dvc add/push/pull/repro`,
  проверки `Pandera` и `Great Expectations`, метрики качества данных.
- [01_theory/data_validation_and_dvc.md](./01_theory/data_validation_and_dvc.md) —
  4 измерения качества данных, сравнение `Pydantic` vs `Pandera` vs `Great
  Expectations`, внутреннее устройство `DVC` (`.dvc`, `dvc.yaml`, `dvc.lock`,
  S3 remote), вопросы для собеседования.
- [02_examples/golden_docs_dataset.json](./02_examples/golden_docs_dataset.json) —
  эталонный синтетический датасет личных документов (врачи, госорганы,
  финансы, заметки, оффтоп) для обучения роутера и тестов RAG.
- [02_examples/validate_docs_schema.py](./02_examples/validate_docs_schema.py) —
  скрипт контрактной валидации датасета (проверка типов, пустых OCR-строк,
  дубликатов, баланса классов и маскирования ПДн).
- [02_examples/dvc.yaml](./02_examples/dvc.yaml) — декларативный пайплайн
  `DVC` из трёх стадий (`validate` → `train` → `evaluate`).
- [03_exercises/README.md](./03_exercises/README.md) — 3 практических
  упражнения (🐳 Tier 1).
- [04_exercises_answers/answers.md](./04_exercises_answers/answers.md) —
  разбор решений и ожидаемый вывод.

## Как проходить

1. Прочитать [01_theory/data_validation_and_dvc.md](./01_theory/data_validation_and_dvc.md).
2. Изучить эталонный набор `02_examples/golden_docs_dataset.json` и
   прогнать валидатор `./02_examples/validate_docs_schema.py`.
3. Выполнить упражнения из [03_exercises/README.md](./03_exercises/README.md).

## Когда двигаться дальше

- Можете объяснить, когда использовать `Pydantic` (одиночный JSON-запрос),
  когда `Pandera` (векторная проверка `DataFrame`), а когда `Great
  Expectations` (витрины данных и HTML-отчёты Data Docs).
- Понимаете, что лежит внутри файла `.dvc` и `dvc.lock` и как `dvc repro`
  определяет, какие шаги пайплайна нужно пересчитать.
- Далее: [04_experiment_tracking](../04_experiment_tracking/).
