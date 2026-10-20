# 07. CI/CD для ML и Quality Gates (ML & LLM CI/CD)

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка
> по четырем типам тестов в ML, поведенческим инвариантам, `promptfoo`
> для LLM/RAG и гейту промоушена `@challenger` → `@champion`.

## Зачем

В обычном backend-разработке зеленый `pytest` означает, что код можно
катить в прод. В ML код может быть синтаксически безупречным, но модель
внутри него после переобучения стала путать медицинские анализы со
справками из налоговой или замедлилась в 4 раза.

Раздел показывает, как построить **непрерывную интеграцию и доставку для
моделей (CI/CD + CT)**: тестировать данные, код, поведенческие
инварианты модели (Minimum Functionality & Directional Tests), промпты
(`promptfoo`) и блокировать выкатку через автоматический **Quality
Gate**.

## Пререквизиты

- [CI/CD](../../6_cicd/) (GitHub Actions / GitLab CI).
- [03. Валидация данных и DVC](../03_data_validation_and_dvc/).
- [04. Трекинг экспериментов и реестр моделей](../04_experiment_tracking/).

## Файлы

- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка по ML CI/CD и Quality
  Gates.
- `01_theory/`
  - [cicd_for_ml.md](./01_theory/cicd_for_ml.md) — пирамида тестирования
    в ML, инварианты CheckList, Quality Gate (`@challenger` vs
    `@champion`), CI для LLM/RAG (`promptfoo`) и 10 Q&A.
- `02_examples/`
  - [test_router_invariants.py](./02_examples/test_router_invariants.py)
    — исполняемый скрипт проверки модели классификатора документов на
    4 класса инвариантов (схема выхода, инвариантность к регистру/шуму,
    Minimum Functionality Tests на критичных документах, бюджет
    латентности `< 5 мс` и Quality Gate против `@champion`).
  - [github_actions_mlops.yml](./02_examples/github_actions_mlops.yml) —
    эталонный пайплайн GitHub Actions для валидации данных, прогона
    инвариантов и промоушена модели.
- `03_exercises/`
  - [README.md](./03_exercises/README.md) — задания на тестирование и
    блокировку деградировавшей модели.
- `04_exercises_answers/`
  - [answers.md](./04_exercises_answers/answers.md) — разбор решений.

## Как проходить

1. Прочитайте [теорию](./01_theory/cicd_for_ml.md).
2. Запустите `./02_examples/test_router_invariants.py` на хосте и
   убедитесь, что все проверки и Quality Gate проходят.
3. Выполните упражнения из [03_exercises/README.md](./03_exercises/README.md).

## Когда двигаться дальше

Вы готовы к разделу [08. Хранилища признаков (Feature Stores)](../08_feature_stores/),
если:
- знаете, чем `Minimum Functionality Test (MFT)` и `Invariance Test`
  отличаются от обычной метрики `F1-macro`;
- можете написать скрипт Quality Gate, который не пускает в прод модель
  с просадкой на критическом срезе данных.
