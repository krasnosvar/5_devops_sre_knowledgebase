# Упражнения — Model Serving

Стенд: 🐳 Tier 1 — Docker (CPU-only, без GPU)

## 01 — Запустить vLLM с маленькой моделью (CPU)

```bash
# Qwen2.5-0.5B — маленькая модель, работает на CPU
docker run -d \
  --name vllm-demo \
  -p 8000:8000 \
  -e HF_TOKEN=${HF_TOKEN:-} \
  vllm/vllm-openai:latest \
  --model Qwen/Qwen2.5-0.5B-Instruct \
  --device cpu \
  --max-model-len 2048

# Дождаться запуска (2-3 минуты)
docker logs -f vllm-demo | grep "Application startup"

# Проверить доступные модели
curl -s http://localhost:8000/v1/models | jq .

# Отправить запрос
curl -s http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen2.5-0.5B-Instruct",
    "messages": [{"role": "user", "content": "What is Kubernetes in one sentence?"}],
    "max_tokens": 100
  }' | jq '.choices[0].message.content'

docker rm -f vllm-demo
```

## 02 — BentoML: упаковать sklearn модель

```python
# train_and_save.py
import bentoml
from sklearn.datasets import load_iris
from sklearn.ensemble import RandomForestClassifier

# Обучить
X, y = load_iris(return_X_y=True)
clf = RandomForestClassifier(n_estimators=10, random_state=42)
clf.fit(X, y)

# Сохранить в BentoML store
saved = bentoml.sklearn.save_model("iris_classifier", clf,
    metadata={"accuracy": clf.score(X, y)})
print(f"Saved: {saved}")
```

```python
# service.py
import bentoml
import numpy as np
from bentoml.io import NumpyNdarray

runner = bentoml.sklearn.get("iris_classifier:latest").to_runner()
svc = bentoml.Service("iris_svc", runners=[runner])

@svc.api(input=NumpyNdarray(), output=NumpyNdarray())
def predict(data: np.ndarray) -> np.ndarray:
    return runner.predict.run(data)
```

```bash
pip install bentoml scikit-learn
python train_and_save.py
bentoml serve service:svc --reload

# Тест
curl -s http://localhost:3000/predict \
  -H "Content-Type: application/json" \
  -d "[[5.1, 3.5, 1.4, 0.2]]"
# Вернёт: [0] (setosa)
```

## 03 — A/B тест: две версии модели

**Задача:** Поднять два экземпляра сервиса с разными версиями модели,
настроить nginx для разделения трафика 80/20.

```nginx
# nginx.conf
upstream model_v1 { server model-v1:3000; }
upstream model_v2 { server model-v2:3000; }

split_clients "${remote_addr}" $model_backend {
    80%    model_v1;
    *      model_v2;
}

server {
    listen 80;
    location /predict {
        proxy_pass http://$model_backend;
    }
}
```

```bash
# Запустить 100 запросов и посмотреть распределение версий
for i in $(seq 100); do
  curl -s http://localhost/predict \
    -H "Content-Type: application/json" \
    -d "[[5.1, 3.5, 1.4, 0.2]]" \
    -w "\n" | jq -r .version
done | sort | uniq -c
# Ожидаем ~80 ответов от v1, ~20 от v2
```
