# Ответы к упражнениям — Экосистема Hugging Face и форматы моделей

## Упражнение 1 — Разбор бинарного заголовка `.safetensors` без загрузки весов

Команды для запуска демонстрационного скрипта и подсчёта объёма тензоров
по заголовку:

```bash
python3 ../02_examples/inspect_safetensors_and_onnx.py
```

Ожидаемый вывод:

```text
=== 1. Почему формат pickle (.pkl / .pt) опасен (RCE при загрузке) ===
  Размер сериализованного pickle-блоба: 173 байт
  Вызываем pickle.loads(payload)...
  [!] СРАБОТАЛ __reduce__ ВНУТРИ pickle.loads() ДО вызова predict()!

=== 2. Инспекция бинарного заголовка .safetensors (Zero-Copy Header) ===
  Файл: doc_router.safetensors (общий размер: 348 байт)
  Первые 8 байт (uint64) -> длина JSON-заголовка: 280 байт
  Смещение начала буфера сырых тензоров: 288 байт
  Метаданные: {'format': 'pt', 'project': 'personal_docs_vault_router', 'categories': 'medicine,gov,finance,notes'}
  Тензоры внутри файла:
    - classifier.weight    dtype=F32 shape=[4, 3] bytes=[0..48] (48 B)
    - classifier.bias      dtype=F32 shape=[3] bytes=[48..60] (12 B)
```

**Почему так:** спецификация `safetensors` гарантирует, что первые 8 байт
хранят размер JSON-заголовка (`uint64` little-endian), а в самом JSON нет
исполняемых инструкций — только имена слоёв, типы (`F32`/`F16`) и смещения
`data_offsets`. Это позволяет мгновенно проверять структуру модели до
выделения гигабайтов оперативной памяти.

---

## Упражнение 2 — Детерминированное скачивание с Hugging Face и офлайн-режим

Команды для настройки кэша, выборочной загрузки конфигов и проверки
симлинков:

```bash
export HF_HOME="$HOME/.cache/mlops-models/hf"
mkdir -p "$HF_HOME"

# Скачиваем только JSON-конфиги без гигабайтных весов через uvx:
uvx --from huggingface_hub hf download intfloat/multilingual-e5-small \
  config.json tokenizer_config.json

# Проверяем структуру симлинков и блобов в кэше:
ls -la "$HF_HOME/hub/models--intfloat--multilingual-e5-small/snapshots/"*

# Проверяем работу в строгом офлайн-режиме (без обращения в интернет):
HF_HUB_OFFLINE=1 uvx --from huggingface_hub hf download \
  intfloat/multilingual-e5-small config.json
```

Ожидаемый вывод:

```text
total 0
lrwxrwxrwx. 1 user user 52 ... config.json -> ../../blobs/4e8b...
lrwxrwxrwx. 1 user user 52 ... tokenizer_config.json -> ../../blobs/9a1c...
/home/user/.cache/mlops-models/hf/hub/models--intfloat--multilingual-e5-small/snapshots/.../config.json
```

**Почему так:** файлы внутри `snapshots/<commit_sha>/` являются
символическими ссылками на контент-адресуемые файлы в `blobs/<sha256>`.
При включённом `HF_HUB_OFFLINE=1` клиент даже не пытается открывать
TCP-соединение к `huggingface.co`, а сразу возвращает путь к закэшированному
снапшоту.

---

## Упражнение 3 — Сборка кастомного `Modelfile` с фиксацией потоков CPU

Команды для проверки P-ядер и сборки модели в контейнере Ollama:

```bash
# 1. Проверяем число физических P-ядер (на Intel 155H это ядра 0..5 = 6 ядер)
lscpu -e=CPU,CORE,MAXMHZ | head -n 13

# 2. Запускаем контейнер Ollama с привязкой к P-ядрам и общим томом кэша
docker run -d --name ollama-docs \
  --cpuset-cpus="0-11" \
  -p 11434:11434 \
  -v "$HOME/.cache/mlops-models/ollama:/root/.ollama" \
  -v "$(pwd)/../02_examples:/workspace:ro" \
  ollama/ollama:latest

# 3. Для быстрой проверки собираем образ на маленькой модели qwen2.5:0.5b
docker exec ollama-docs ollama pull qwen2.5:0.5b
docker exec ollama-docs sh -c \
  'sed "s/qwen2.5:7b-instruct-q4_K_M/qwen2.5:0.5b/" /workspace/Modelfile.doc-assistant > /tmp/Modelfile && ollama create doc-assistant -f /tmp/Modelfile'

# 4. Тестируем классификацию и суммаризацию документа
docker exec ollama-docs ollama run doc-assistant \
  "Документ: Клинический анализ крови от 14.02.2026. Гемоглобин 142 г/л, Ферритин 45 нг/мл."

# 5. Останавливаем тестовый контейнер (скачанные веса останутся в кэше на хосте)
docker rm -f ollama-docs
```

Ожидаемый вывод (приблизительный):

```text
gathering model components ...
success
Категория: medicine
Дата: 2026-02-14
Суть: Результаты клинического анализа крови (гемоглобин 142 г/л, ферритин 45 нг/мл — в пределах нормы).
```

**Почему так:** директива `PARAMETER num_thread 6` внутри `Modelfile` и
флаг `--cpuset-cpus="0-11"` на уровне Docker cgroups гарантируют, что
потоки генерации `llama.cpp` работают исключительно на быстрых P-ядрах и
не тормозятся на барьерах синхронизации из-за медленных E-ядер.
