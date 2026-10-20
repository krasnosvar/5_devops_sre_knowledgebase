# Хранилища признаков (Feature Stores) — шпаргалка

Теория: [feature_stores.md](./01_theory/feature_stores.md).
`⚠️` = опасная команда / частая ловушка.

## Архитектура Dual Store в Feast

| Контур | Хранилище | Метод в Feast | Латентность | Назначение |
| :--- | :--- | :--- | :--- | :--- |
| **Offline Store** | Parquet в S3, ClickHouse, BigQuery, Postgres | `get_historical_features()` | Секунды / минуты | Сборка обучающей выборки с `Point-in-Time Join` |
| **Online Store** | Redis, DynamoDB, SQLite (dev) | `get_online_features()` | `1–5 мс` | Быстрое чтение последних значений признаков по `entity_id` на инференсе |

## Основные команды CLI `feast`

| Команда | Что делает |
| :--- | :--- |
| `feast apply` | Регистрирует описания `Entity`, `FeatureView`, `FeatureService` в реестре и создает схемы в Online Store |
| `feast materialize <start> <end>` | Перекладывает свежие значения признаков из Offline Store в Online Store (Redis) за указанный интервал |
| `feast materialize-incremental <now>` | Догружает в Online Store только дельту с момента прошлой материализации (запускается по cron) |

## Частые ловушки

| Симптом | Причина | Решение |
| :--- | :--- | :--- |
| Офлайн `ROC-AUC = 0.99`, в продакшене `0.55` | Обычный `JOIN` по `user_id` без учета времени события (`Time-Travel Leakage`) | Использовать `get_historical_features()` с колонкой `event_timestamp` (`ASOF JOIN`) |
| В онлайне приходят `None` вместо признаков | Установлен слишком маленький `ttl` в `FeatureView` или упал cron `materialize-incremental` | Проверить `ttl` и настроить мониторинг свежести материализации |

> Проверка: справочный раздел (без отдельной лабы).
