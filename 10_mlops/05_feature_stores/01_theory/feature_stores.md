# Feature Stores

## Проблема без Feature Store

```
Data Scientist → обучает модель на feature X (вычисленной определённым образом)
ML Engineer → деплоит модель, вычисляет feature X в runtime (чуть по-другому)
→ Training-serving skew: модель обучена на одних данных, инферится на других

+ Дублирование кода: команда A и команда B независимо пишут "средний чек за 30 дней"
+ Нет версионирования: какие features использовались для модели v2.3?
```

## Feature Store решает

1. **Consistency** — одна реализация feature и для обучения, и для serving
2. **Reuse** — feature "средний чек за 30 дней" один раз, используют все модели
3. **Versioning** — какие features и с какими значениями были у модели в production
4. **Low-latency serving** — online store для real-time inference

## Архитектура Feature Store

```
                    Batch pipeline (daily)
                         │
Raw Data ───────────────►│ Feature computation
                         │
                         ▼
              ┌─────────────────────┐
              │  Offline Store      │  ← для обучения
              │  (Parquet, BigQuery,│
              │   Delta Lake, S3)   │
              └─────────────────────┘
                         │
              Materialization (scheduled job)
                         │
                         ▼
              ┌─────────────────────┐
              │  Online Store       │  ← для serving (low latency)
              │  (Redis, DynamoDB,  │
              │   Cassandra)        │
              └─────────────────────┘
                         │
              Feature serving API
                         │
              Model inference (real-time)
```

## Feast — open-source Feature Store

```python
# feature_store.yaml
project: fraud_detection
registry: data/registry.db
provider: local        # или: gcp, aws

offline_store:
  type: file           # или: bigquery, redshift, spark

online_store:
  type: sqlite         # dev; prod: redis, dynamodb

entity_key_serialization_version: 2
```

```python
# features.py — определить features
from datetime import timedelta
from feast import Entity, FeatureService, FeatureView, Field, FileSource
from feast.types import Float32, Int64, String

# Entity — ключ (по чему делаем lookup)
user = Entity(name="user_id", join_keys=["user_id"])

# Source данных
user_stats_source = FileSource(
    path="data/user_stats.parquet",
    timestamp_field="event_timestamp",
)

# Feature View — набор features для entity
user_stats_fv = FeatureView(
    name="user_stats",
    entities=[user],
    ttl=timedelta(days=1),
    schema=[
        Field(name="avg_transaction_30d", dtype=Float32),
        Field(name="transaction_count_7d", dtype=Int64),
        Field(name="country", dtype=String),
        Field(name="is_premium", dtype=Int64),
    ],
    online=True,         # материализовать в online store
    source=user_stats_source,
)

# Feature Service — набор features для конкретной модели
fraud_features = FeatureService(
    name="fraud_detection_v2",
    features=[
        user_stats_fv[["avg_transaction_30d", "transaction_count_7d", "country"]],
    ]
)
```

```python
# Работа с Feature Store
from feast import FeatureStore

store = FeatureStore(repo_path=".")

# 1. Применить определения
# feast apply

# 2. Материализовать в online store
store.materialize_incremental(end_date=datetime.now())

# 3. Получить features для обучения (historical)
entity_df = pd.DataFrame({
    "user_id": [1001, 1002, 1003],
    "event_timestamp": pd.to_datetime(["2024-01-15", "2024-01-15", "2024-01-15"])
})

training_data = store.get_historical_features(
    entity_df=entity_df,
    features=["user_stats:avg_transaction_30d", "user_stats:country"]
).to_df()

# 4. Получить features для serving (online, low-latency)
online_features = store.get_online_features(
    features=["user_stats:avg_transaction_30d", "user_stats:country"],
    entity_rows=[{"user_id": 1001}, {"user_id": 1002}]
).to_df()
```

## Когда нужен Feature Store

**Нужен:**
- 3+ ML моделей используют одинаковые features
- Нужен real-time serving с latency < 50ms
- Training-serving skew — реальная проблема
- Нужно воспроизвести эксперимент через полгода (point-in-time features)

**Не нужен (пока):**
- 1-2 модели, batch inference
- Небольшая команда (операционная сложность > польза)
- Simple features (без сложных window aggregations)

## Альтернативы

- **Tecton** — enterprise (managed, дорого, production-grade)
- **Hopsworks** — open-source, более полный стек (включая training pipeline)
- **Vertex AI Feature Store** — GCP managed
- **AWS SageMaker Feature Store** — AWS managed
- **Redis + простой wrapper** — если нужно только online store без сложности
