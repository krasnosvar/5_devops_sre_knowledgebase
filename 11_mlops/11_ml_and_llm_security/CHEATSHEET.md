# AI DevSecOps: Безопасность ML и LLM — шпаргалка

Теория: [ml_and_llm_security.md](./01_theory/ml_and_llm_security.md).
`⚠️` = опасная команда / частая ловушка.

## Базы уязвимостей и фреймворки угроз AI/ML

| Ресурс | Что внутри | Когда открывать инженеру |
| :--- | :--- | :--- |
| **Huntr (Protect AI VulnDB)** (`huntr.com/bounties`) | Крупнейшая база реальных CVE в `MLflow`, `Ollama`, `vLLM`, `llama.cpp`, `LangChain`, `Ray`, `PyTorch` | Перед деплоем любого open-source MLOps-инструмента наружу |
| **OWASP Top 10 for LLM (2025)** | 10 главных уязвимостей LLM-приложений (`LLM01 Prompt Injection`, `LLM02 Sensitive Info Disclosure`, `LLM03 Supply Chain`...) | При проектировании архитектуры RAG / AI-агентов |
| **OWASP Machine Learning Security Top 10** | Угрозы классического ML (`Data Poisoning`, `Model Inversion`, `Membership Inference`, `Unsafe Deserialization`) | При ревью пайплайнов обучения и Model Registry |
| **MITRE ATLAS** (`atlas.mitre.org`) | Матрица тактик и техник атак на ML-системы (аналог MITRE ATT&CK для AI) | При моделировании угроз (Threat Modeling) и расследовании инцидентов |
| **AI Incident Database** (`incidentdatabase.ai`) | Каталог реальных публичных сбоев, утечек и галлюцинаций AI в продакшене | Для разбора постмортемов и обучения команды |

## Инструменты безопасности по этапам пайплайна

| Этап | Инструмент | Команда / Назначение |
| :--- | :--- | :--- |
| **Сканирование файлов весов в CI** | **ModelScan** (`Protect AI`) | `modelscan -p ./models/model.pkl` (ищет RCE-инструкции в `.pkl`, `.pt`, `.h5`, SavedModel) |
| **Декомпиляция подозрительного Pickle** | **Fickling** (`Trail of Bits`) | `fickling --check-safety model.pkl` (статический анализ AST виртуальной машины Pickle без выполнения кода) |
| **Red-Teaming и пентест LLM** | **Garak** (`NVIDIA`) / **Promptfoo** | `garak --model_type ollama --model_name qwen2.5:7b --probes promptinject` |
| **Фильтрация PII и Prompt Injection на лету** | **Microsoft Presidio** / **LLM Guard** | Детекция и маскирование ФИО, телефонов, СНИЛС, ИНН, карт до отправки в LLM и логи |

## Безопасная загрузка весов (Safe Defaults)

```python
# ⚠️ ОПАСНО: выполняет произвольный код из архива pickle!
# model = torch.load("untrusted_model.pt")

# БЕЗОПАСНО (вариант 1): использовать safetensors / ONNX / GGUF
from safetensors.torch import load_file
tensors = load_file("model.safetensors")

# БЕЗОПАСНО (вариант 2): разрешить только чистые тензоры без вызова функций
state_dict = torch.load("model.pt", weights_only=True)
```

> Проверка: `./02_examples/pii_and_security_scanner.py` выполнен на Python 3.14.8.
