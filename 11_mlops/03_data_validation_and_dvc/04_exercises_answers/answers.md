# Ответы к упражнениям — Качество, валидация и версионирование данных

## Упражнение 1 — Проверка контракта данных и отлов Data Leakage

Команды для проверки перехвата дубликата текста с изменёнными пробелами:

```bash
python3 -c '
import json, sys
sys.path.insert(0, "../02_examples")
from validate_docs_schema import validate_dataset

with open("../02_examples/golden_docs_dataset.json") as f:
    docs = json.load(f)["documents"]

dup = dict(docs[0])
dup["doc_id"] = "med_999"
dup["text"] = "   " + dup["text"].replace(" ", "   ")
docs.append(dup)

for err in validate_dataset(docs):
    print(err)
'
```

Ожидаемый вывод:

```text
[med_999] Полный дубликат текста с документом [med_001] (Data Leakage!)
```

**Почему так:** перед вычислением `MD5`-хэша строка нормализуется
(`re.sub(r"\s+", " ", text.lower())`), поэтому лишние пробелы или смена
регистра после повторного OCR не позволяют дубликату просочиться в выборку.

---

## Упражнение 2 — Расширение валидатора правилом Consistency

Проверка даты документа на отсутствие дат из будущего:

```bash
python3 -c '
from datetime import datetime

doc_date = "2029-11-14"
parsed = datetime.strptime(doc_date, "%Y-%m-%d").date()
today = datetime.now().date()
if parsed > today:
    print(f"[Consistency Error] Дата документа {parsed} находится в будущем (> {today})!")
'
```

Ожидаемый вывод:

```text
[Consistency Error] Дата документа 2029-11-14 находится в будущем (> 2026-10-16)!
```

**Почему так:** при оптическом распознавании (OCR) цифр на помятых бланках
символ `6` или `0` часто путается с `9` или `8`. Проверка `parsed <= today`
отсекает такие ошибки до попадания метаданных в таблицу реестра и `Qdrant`.

---

## Упражнение 3 — Инициализация DVC во временном репозитории

Команды для проверки работы `DVC` и структуры `.dvc`-файла:

```bash
mkdir -p /tmp/dvc_lab && cd /tmp/dvc_lab
git init -q
cp /home/den/my_projects/00_for_public_git/5_devops_sre_knowledgebase/11_mlops/03_data_validation_and_dvc/02_examples/golden_docs_dataset.json .

# Инициализируем DVC и ставим датасет на трекинг
uvx --from dvc dvc init -q
uvx --from dvc dvc add golden_docs_dataset.json

# Смотрим сгенерированный .dvc файл и кэш
cat golden_docs_dataset.json.dvc
find .dvc/cache/files/md5 -type f

# Удаляем временный стенд
cd / && rm -rf /tmp/dvc_lab
```

Ожидаемый вывод:

```text
outs:
- md5: 8c4a...
  size: 4612
  hash: md5
  path: golden_docs_dataset.json
.dvc/cache/files/md5/8c/4a...
```

**Почему так:** `dvc add` заменяет тяжёлый файл в Git на 4-строчный YAML
указатель с `md5`-хэшем и размером, а сам контент кладёт в контент-адресуемое
хранилище `.dvc/cache/files/md5/<первые_2_символа>/<остальные_30_символов>`.
