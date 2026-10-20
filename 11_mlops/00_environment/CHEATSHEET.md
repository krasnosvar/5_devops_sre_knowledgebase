# Подготовка окружения MLOps и LLMOps — шпаргалка

Подробности и разбор под капотом — в
[environment_setup.md](./01_theory/environment_setup.md).
⚠️ — опасная команда или частая ловушка.

## Управление Python 3.12 через `uv`

| Задача | Команда |
| :--- | :--- |
| Установить Python 3.12 изолированно (не трогая системный Python) | `uv python install 3.12` |
| Зафиксировать Python 3.12 в проекте (`.python-version`) | `uv python pin 3.12` |
| Создать `.venv` и установить зависимости строго по `uv.lock` | `uv sync --frozen` |
| Добавить ML-пакет (например, `onnxruntime`, `pandera`) | `uv add onnxruntime pandera` |
| Запустить скрипт внутри окружения проекта | `uv run python train.py` |
| Разовый запуск CLI-утилиты без установки в проект (`modelscan`, `hf`) | `uvx modelscan -p model.pkl` |
| ⚠️ Ловушка: Python 3.13/3.14 без готовых бинарных колёс (`wheels`) | Всегда фиксируйте `requires-python = ">=3.12,<3.13"` в `pyproject.toml` |

## Гибридный CPU (Intel 155H: P-ядра vs E-ядра)

| Задача | Команда / Настройка |
| :--- | :--- |
| Посмотреть топологию ядер и их максимальные частоты (`MAXMHZ`) | `lscpu -e=CPU,CORE,SOCKET,MAXMHZ` |
| Запустить команду только на P-ядрах (потоки `0-11` на Intel 155H) | `taskset -c 0-11 ./llama-server -t 6 -m model.gguf` |
| Ограничить пул потоков OpenMP / MKL / ONNX Runtime (по числу физ. P-ядер) | `export OMP_NUM_THREADS=6 MKL_NUM_THREADS=6` |
| Привязать контейнер в `docker-compose.yml` к P-ядрам | `cpuset: "0-11"` внутри сервиса |
| ⚠️ Ловушка: запуск `llama.cpp` на все 22 потока (`-t 22`) | Падение скорости в 1.5–2 раза из-за ожидания E-ядер на барьерах синхронизации |

## Единый кэш моделей и офлайн-режим

| Переменная / Путь | Назначение |
| :--- | :--- |
| `export HF_HOME=~/.cache/mlops-models/hf` | Единый каталог кэша весов и датасетов Hugging Face |
| `export HF_HUB_OFFLINE=1` | Запрет сетевых запросов к `huggingface.co` (работа только из локального кэша) |
| `export TORCH_HOME=~/.cache/mlops-models/torch` | Кэш весов PyTorch / Torchvision |
| `export OLLAMA_MODELS=~/.cache/mlops-models/ollama` | Каталог хранения блобов и манифестов моделей Ollama |
| Монтирование кэша в `k3d` (при создании кластера) | `k3d cluster create mlops --volume ~/.cache/mlops-models:/var/lib/ml-cache@all` |

## Проверка симптомов окружения

| Симптом | Куда смотреть и как чинить |
| :--- | :--- |
| `pip` / `uv` компилирует `onnxruntime` или `pyarrow` из C++ исходников | Вы на Python 3.14 — выполните `uv python pin 3.12 && uv sync` |
| Генерация LLM даёт 3–4 ток/с вместо 12 ток/с при 100% загрузке CPU | Процесс размазан по E-ядрам и Hyper-Threading — поставьте `-t 6` и `taskset -c 0-11` |
| Диск забился за вечер после нескольких перезапусков контейнеров | Не проброшен volume с `HF_HOME` — модели скачиваются во временный слой контейнера |
| В `git status` появились `.pdf`, `.jpg` или `.gguf` | Проверьте `.gitignore` и вынесите папку личных документов за пределы репозитория |

> Проверка: `bash -n 02_examples/check_env.sh`, `lscpu -e` (util-linux 2.40); не проверено: создание кластера `k3d` (требует активного демона Docker).
