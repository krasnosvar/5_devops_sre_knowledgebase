# Сквозной проект: Личная база документов — шпаргалка

Теория: [capstone_architecture.md](./01_theory/capstone_architecture.md).
`⚠️` = опасная команда / частая ловушка.

## 4 уровня хранения в Личной базе документов

| Что храним | Где храним | Почему не в Excel напрямую? |
| :--- | :--- | :--- |
| **Оригиналы файлов (PDF, фото чеков, МРТ, видео)** | Папка `~/personal_docs_vault/<year>/<category>/` или S3 (`SeaweedFS`) | В Excel файлы раздувают `.xlsx` до гигабайт и ломаются |
| **Структурированный реестр (дата, орган/врач, сумма, путь к файлу)** | **SQLite / PostgreSQL** + **кнопка выгрузки в `.xlsx`/`.csv`** | Позволяет фильтровать и открывать сводную таблицу в Excel в 1 клик |
| **Чанки текста и векторы (`bge-m3` + `BM25`)** | Векторная БД **Qdrant** | Быстрый гибридный поиск по смыслу и точным номерам за `5 мс` |
| **Модели и метрики экспериментов** | **MLflow Registry** (`@champion`) + кэш `/models/hf_cache` | Версионирование весов `ONNX`-роутера и промптов |

## Быстрые команды запуска

```bash
# 1. Полный самотест пайплайна (Data CI + Router + PII Guardrail + RAG + Excel export)
./11_mlops/13_capstone_project/02_examples/personal_vault_app.py --self-test

# 2. Задать вопрос по базе документов из терминала
./11_mlops/13_capstone_project/02_examples/personal_vault_app.py \
  --query "Какой ферритин был в анализе крови и что назначил гастроэнтеролог?"

# 3. Выгрузить весь реестр документов в таблицу для Excel (UTF-8 BOM)
./11_mlops/13_capstone_project/02_examples/personal_vault_app.py \
  --export-csv /tmp/personal_docs_registry.csv

# 4. Запустить локальный Веб-интерфейс (таблица + поиск + экспорт в Excel)
./11_mlops/13_capstone_project/02_examples/personal_vault_app.py --serve
```

## Правила безопасности для личных документов

| Правило | Реализация |
| :--- | :--- |
| `⚠️` Никогда не класть реальные паспорта/анализы внутрь Git-репозитория | Хранить реальные файлы строго в `~/personal_docs_vault/` (путь задается через `VAULT_DATA_DIR`) |
| `⚠️` Не отправлять сырые СНИЛС/ИНН во внешние облачные API | Локальный инференс на **Intel 155H** (`ONNX` + `Ollama`) + `pseudonymize_russian_pii()` |

> Проверка: `./02_examples/personal_vault_app.py --self-test` выполнен на Python 3.14.8.
