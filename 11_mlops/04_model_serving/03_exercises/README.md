# Упражнения — Model Serving

Стенд: 🐳 Tier 1 — Docker (CPU-only, без GPU)

## 01 — Запустить LLM с маленькой моделью (CPU, OpenAI-совместимый API)

> **Почему не vLLM.** Официальный образ `vllm/vllm-openai` собран под
> NVIDIA CUDA и требует GPU + NVIDIA Container Toolkit; флаг
> `--device cpu` его в CPU-версию не превращает (CPU-бэкенд vLLM — это
> отдельная сборка). Поэтому на CPU-стенде используем Ollama: он отдаёт
> тот же OpenAI-совместимый API (`/v1/models`, `/v1/chat/completions`),
> так что клиентский код не меняется. Альтернатива — `llama-server` из
> llama.cpp с GGUF-моделью. Если GPU есть — вариант с vLLM в
> [теории](../01_theory/model_serving.md).

**Задача:** поднять Ollama в Docker, скачать модель Qwen2.5 0.5B,
получить список моделей и ответ через `/v1/chat/completions`, затем
удалить контейнер.

```bash
docker run -d \
  --name llm-demo \
  -p 11434:11434 \
  -v ollama:/root/.ollama \
  ollama/ollama:latest

# Скачать маленькую модель (~400 MB)
docker exec llm-demo ollama pull qwen2.5:0.5b

# Проверить доступные модели
curl -s http://localhost:11434/v1/models | jq .

# Отправить запрос
curl -s http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5:0.5b",
    "messages": [{"role": "user", "content": "What is Kubernetes in one sentence?"}],
    "max_tokens": 100
  }' | jq -r '.choices[0].message.content'

docker rm -f llm-demo
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
# service.py — API BentoML 1.2+ (старый bentoml.Service/runners
# объявлен устаревшим)
import bentoml
import numpy as np


@bentoml.service
class IrisClassifier:
    def __init__(self) -> None:
        self.model = bentoml.sklearn.load_model("iris_classifier:latest")

    @bentoml.api
    def predict(self, data: np.ndarray) -> np.ndarray:
        return self.model.predict(data)
```

```bash
pip install bentoml scikit-learn
python train_and_save.py
bentoml serve service:IrisClassifier

# Тест (в другом терминале). Тело — JSON с именем аргумента метода.
curl -s -X POST http://localhost:3000/predict \
  -H "Content-Type: application/json" \
  -d '{"data": [[5.1, 3.5, 1.4, 0.2]]}'
# Вернёт: [0] (setosa)
```

## 03 — A/B тест: две версии модели

**Задача:** Поднять два экземпляра сервиса с разными версиями модели
(каждый возвращает в ответе поле `version`), настроить nginx для
разделения трафика 80/20 и опубликовать его на `localhost:8080`.
Всё — в одном `docker-compose.yml`.

```nginx
# nginx.conf
upstream model_v1 { server model-v1:3000; }
upstream model_v2 { server model-v2:3000; }

# Ключ — $request_id: при $remote_addr все запросы с одного хоста
# (curl с localhost) уйдут в ОДНУ версию.
split_clients "${request_id}" $model_backend {
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
  curl -s http://localhost:8080/predict \
    -H "Content-Type: application/json" \
    -d '{"data": [[5.1, 3.5, 1.4, 0.2]]}' \
    -w "\n" | jq -r .version
done | sort | uniq -c
# Ожидаем ~80 ответов от v1, ~20 от v2
```
