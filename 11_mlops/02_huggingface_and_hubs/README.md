# 02. Экосистема Hugging Face, реестры и форматы моделей

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка по
> CLI `huggingface-cli`, форматам весов (`safetensors`, `GGUF`, `ONNX`),
> `ORAS` и `optimum`.

## Зачем

В современном MLOps и LLMOps почти ни одна модель не пишется с нуля:
базовые трансформеры, эмбеддеры (`bge-m3`), реранкеры и LLM (`Qwen`,
`Llama`, `Gemma`) берутся из внешних хабов. При этом инженер на практике
сталкивается с четырьмя критическими вопросами:

1. **Откуда и как безопасно скачивать модели:** как зафиксировать точную
   ревизию весов (`commit SHA`), чтобы завтра код в продакшне не сломался
   от чужого коммита в ветку `main` на Hugging Face, и как раздать веса в
   закрытом контуре без интернета (`HF_HUB_OFFLINE=1`, `ORAS / OCI`).
2. **Что лежит внутри файла модели:** почему классический `.pt` / `.pkl`
   (`pickle`) позволяет выполнить произвольный код (RCE) прямо при загрузке,
   и почему индустрия перешла на `safetensors`, `GGUF` и `ONNX`.
3. **Как адаптировать и ускорить модель под своё железо:** как с помощью
   `optimum` сконвертировать модель в `ONNX` (или `OpenVINO` под Intel CPU /
   Arc iGPU) и как через `peft` навесить лёгкий LoRA-адаптер.
4. **Какие ещё хабы и реестры используются в работе:** `Ollama Registry` и
   `Modelfile`, `ModelScope` (экосистема Qwen), `NVIDIA NGC` и хранение
   моделей прямо в корпоративном Harbor / GitLab Registry как OCI-артефактов.

## Пререквизиты

- [00_environment](../00_environment/) — настроенный `uv`, Python 3.12 и
  каталог кэша `~/.cache/mlops-models`.
- [01_ml_lifecycle](../01_ml_lifecycle/) — роль реестра моделей в жизненном
  цикле.
- [3_containers/02_image_layers](../../3_containers/02_image_layers/) —
  устройство OCI-слоёв и манифестов (поможет понять `ORAS` и `Modelfile`).

## Файлы

- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: команды `huggingface-cli`,
  сравнение форматов весов, экспорт в `ONNX`, упаковка в OCI через `oras`.
- [01_theory/huggingface_and_model_hubs.md](./01_theory/huggingface_and_model_hubs.md) —
  устройство HF Hub и кэша, альтернативные хабы (`Ollama`, `ModelScope`,
  `NGC`, `ORAS`), бинарная анатомия `pickle` vs `safetensors` vs `GGUF` vs
  `ONNX`, библиотеки `transformers`/`peft`/`optimum`, вопросы для интервью.
- [02_examples/inspect_safetensors_and_onnx.py](./02_examples/inspect_safetensors_and_onnx.py) —
  практический скрипт: разбор бинарного заголовка `safetensors` без чтения
  тензоров в RAM + обучение рубрикатора личных документов и его экспорт в
  `ONNX` с проверкой в `onnxruntime`.
- [02_examples/Modelfile.doc-assistant](./02_examples/Modelfile.doc-assistant) —
  пример `Modelfile` для сборки локального LLM-ассистента по документам с
  лимитом потоков под 6 P-ядер процессора.
- [03_exercises/README.md](./03_exercises/README.md) — 3 практических
  упражнения (CPU-only, 🐳 Tier 1).
- [04_exercises_answers/answers.md](./04_exercises_answers/answers.md) —
  разбор решений и пошаговые команды.

## Как проходить

1. Прочитать [01_theory/huggingface_and_model_hubs.md](./01_theory/huggingface_and_model_hubs.md).
2. Запустить пример `./02_examples/inspect_safetensors_and_onnx.py` и
   посмотреть, как устроен заголовок `safetensors` и граф `ONNX`.
3. Выполнить упражнения из [03_exercises/README.md](./03_exercises/README.md)
   и сверить результаты с ответами.

## Когда двигаться дальше

- Можете объяснить, почему `safetensors` безопасен и загружается через
  `mmap` без двойного расхода RAM, а `pickle` опасен RCE-инъекцией.
- Умеете скачать модель с Hugging Face с жёсткой привязкой к `revision` и
  запустить код с `HF_HUB_OFFLINE=1`.
- Понимаете, чем отличаются форматы `safetensors`, `GGUF` и `ONNX` и для
  какого рантайма предназначен каждый из них.
- Далее: [03_data_validation_and_dvc](../03_data_validation_and_dvc/).
