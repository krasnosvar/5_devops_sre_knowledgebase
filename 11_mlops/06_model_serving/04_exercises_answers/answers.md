# Ответы — Model Serving

Упражнения: [../03_exercises/README.md](../03_exercises/README.md).
Стенд: 🐳 Tier 1 — Docker, без GPU.

## Упражнение 01 — Запустить LLM с маленькой моделью (CPU, OpenAI-совместимый API)

```bash
docker run -d \
  --name llm-demo \
  -p 11434:11434 \
  -v ollama:/root/.ollama \
  ollama/ollama:latest

docker exec llm-demo ollama pull qwen2.5:0.5b

curl -s http://localhost:11434/v1/models | jq .

curl -s http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5:0.5b",
    "messages": [{"role": "user", "content": "What is Kubernetes in one sentence?"}],
    "max_tokens": 100
  }' | jq -r '.choices[0].message.content'

docker rm -f llm-demo
# модель лежит в томе ollama; удалить и её:
docker volume rm ollama
```

Ожидаемый вывод:

```text
...
success
{
  "object": "list",
  "data": [
    {"id": "qwen2.5:0.5b", "object": "model", "created": ..., "owned_by": "library"}
  ]
}
Kubernetes is an open-source platform that automates the deployment,
scaling, and management of containerized applications.
```

Почему так:
- Образ `vllm/vllm-openai` собран под CUDA и без NVIDIA GPU не стартует,
  `--device cpu` это не меняет. Ollama на CPU отдаёт тот же
  OpenAI-совместимый API, поэтому клиентский код (`/v1/chat/completions`)
  при переезде на vLLM с GPU не меняется — меняются только URL и имя
  модели.
- Модель 0.5B отвечает за секунды даже на CPU, но качество ответов
  заметно ниже больших моделей — для лабы это нормально.
- Альтернатива Ollama — `llama-server` из llama.cpp с GGUF-файлом модели:
  у него тоже есть `/v1/chat/completions`.

## Упражнение 02 — BentoML: упаковать sklearn модель

Файлы `train_and_save.py` и `service.py` — как в условии упражнения.

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install bentoml scikit-learn
python train_and_save.py
bentoml models list

bentoml serve service:IrisClassifier
```

Во втором терминале:

```bash
curl -s -X POST http://localhost:3000/predict \
  -H "Content-Type: application/json" \
  -d '{"data": [[5.1, 3.5, 1.4, 0.2]]}'
```

Ожидаемый вывод:

```text
Saved: Model(tag="iris_classifier:<случайный тег>")
...
[0]
```

Почему так:
- `save_model` кладёт модель в локальный store (`~/bentoml/models`) с
  версией-тегом; сервис грузит `iris_classifier:latest` один раз в
  `__init__`, а не на каждый запрос.
- В API BentoML 1.2+ тело запроса — JSON, где ключи совпадают с именами
  аргументов метода (`data`). Голый массив `[[...]]` из старого API
  (`bentoml.io.NumpyNdarray`) здесь не подойдёт.
- `[0]` — класс setosa: этот образец взят из обучающей выборки Iris.

## Упражнение 03 — A/B тест: две версии модели

Готовый стенд — [ab_test/](./ab_test/):
- [ab_test/docker-compose.yml](./ab_test/docker-compose.yml) — два
  экземпляра модели (`model-v1`, `model-v2`) и nginx на `localhost:8080`;
- [ab_test/model_stub.py](./ab_test/model_stub.py) — заглушка модели:
  `POST /predict` возвращает `{"prediction": [0], "version": "<v1|v2>"}`;
- [ab_test/nginx.conf](./ab_test/nginx.conf) — `split_clients` 80/20.

```bash
cd ab_test
docker compose config -q
docker compose up -d
docker compose ps

for i in $(seq 100); do
  curl -s http://localhost:8080/predict \
    -H "Content-Type: application/json" \
    -d '{"data": [[5.1, 3.5, 1.4, 0.2]]}' \
    -w "\n" | jq -r .version
done | sort | uniq -c

docker compose down
```

Ожидаемый вывод (числа плавают от запуска к запуску):

```text
     87 v1
     13 v2
```

Почему так:
- `split_clients` хеширует ключ (MurmurHash2) и по проценту выбирает
  upstream. Ключ `$request_id` уникален для каждого запроса, поэтому
  доли близки к 80/20 уже на 100 запросах, но не равны им точно.
- С ключом `$remote_addr` все запросы с одного хоста получат ОДИН и тот же
  backend — так делают «липкий» A/B по пользователю, но с одного `curl`
  распределения не увидеть.
- Вместо настоящей модели — заглушка: упражнение проверяет разделение
  трафика, а не качество предсказаний. Для реального сервиса подставьте
  образ из упражнения 02 (`bentoml containerize`) с портом 3000.
