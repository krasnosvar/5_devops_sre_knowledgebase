# Экосистема Hugging Face и форматы моделей — шпаргалка

Подробности и разбор под капотом — в
[huggingface_and_model_hubs.md](./01_theory/huggingface_and_model_hubs.md).
⚠️ — опасная команда или частая ловушка.

## Работа с Hugging Face Hub (`huggingface-cli` / `hf`)

| Задача | Команда |
| :--- | :--- |
| Авторизоваться токеном (для gated-моделей вроде Llama / Gemma) | `huggingface-cli login --token $HF_TOKEN` |
| Скачать только один GGUF-файл из репозитория в кэш | `huggingface-cli download Qwen/Qwen2.5-7B-Instruct-GGUF qwen2.5-7b-instruct-q4_k_m.gguf` |
| Скачать репозиторий по точному `commit SHA` (`--revision`) | `huggingface-cli download BAAI/bge-m3 --revision 5617a9f --include "*.safetensors" "*.json"` |
| Посмотреть размер и список моделей в локальном кэше `HF_HOME` | `huggingface-cli scan-cache` |
| Удалить неиспользуемые ревизии из кэша | `huggingface-cli delete-cache` |
| ⚠️ Ловушка: `from_pretrained("org/model")` без `revision="..."` | В проде всегда фиксируйте `revision="<commit_sha>"`, иначе чужой пуш в `main` изменит модель |

## Сравнение форматов файлов моделей

| Формат | Расширение | Безопасность | `mmap` (zero-copy) | Где и когда использовать |
| :--- | :--- | :--- | :--- | :--- |
| **Pickle / PyTorch** | `.pkl`, `.pt`, `.bin` | ⚠️ **Опасно (RCE!)** — исполняет произвольный код при загрузке | Нет | Устаревший формат; в проде запрещать или сканировать через `modelscan` |
| **Safetensors** | `.safetensors` | Безопасно (чистый JSON + буфер байтов) | Да | Хранение и обмен весами в `transformers`, `peft`, дообучение |
| **GGUF** | `.gguf` | Безопасно (один бинарный файл: веса + словарь) | Да | Локальный инференс LLM на CPU / iGPU / GPU через `llama.cpp` и `Ollama` |
| **ONNX** | `.onnx` | Безопасно (граф Protobuf + веса) | Частично | Быстрый продакшн-инференс классических моделей, эмбеддеров и реранкеров в `ONNX Runtime` |
| **OpenVINO IR** | `.xml` + `.bin` | Безопасно | Да | Ускорение на процессорах Intel (P-ядра, встроенная графика **Intel Arc**, **NPU**) |

## Конвертация и доставка весов (`optimum`, `Ollama`, `ORAS`)

| Задача | Команда |
| :--- | :--- |
| Экспортировать трансформер с HF в формат `ONNX` | `optimum-cli export onnx --model BAAI/bge-m3 --task feature-extraction ./bge-m3-onnx/` |
| Экспортировать модель под Intel CPU / Arc iGPU (`OpenVINO int8`) | `optimum-cli export openvino --model BAAI/bge-m3 --weight-format int8 ./bge-m3-ov/` |
| Собрать локальный образ модели в `Ollama` из `Modelfile` | `ollama create doc-assistant -f Modelfile.doc-assistant` |
| Запушить файл модели `.onnx` / `.gguf` в обычный Docker Registry (`Harbor`/`GitLab`) | `oras push registry.local/ml/router:v1.0 model.onnx:application/octet-stream` |
| Скачать модель из корпоративного OCI/Docker Registry | `oras pull registry.local/ml/router:v1.0` |

> Проверка: `python3 02_examples/inspect_safetensors_and_onnx.py` (safetensors, skl2onnx, onnxruntime); не проверено: `oras push` (требует поднятого OCI-реестра).
