#!/usr/bin/env python3
"""Контрактная валидация датасета личных документов (Data Quality Gate).

Проверяет четыре измерения качества данных:
1. Completeness: отсутствие пустых полей и слишком коротких OCR-текстов.
2. Validity: допустимые категории (enum), корректный формат дат YYYY-MM-DD,
   доля осмысленных символов (защита от битого OCR).
3. Uniqueness: отсутствие дубликатов doc_id и дубликатов по хэшу текста
   (защита от Data Leakage между train и test).
4. Consistency & Privacy: проверка отсутствия незамаскированных номеров
   СНИЛС и паспортов РФ перед отправкой в обучение.
"""

from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
import sys

ALLOWED_CATEGORIES = {"medicine", "gov", "finance", "notes", "offtopic"}
# Регулярные выражения для поиска незамаскированных чувствительных ПДн (PII)
SNILS_RE = re.compile(r"\b\d{3}-\d{3}-\d{3}[ -]\d{2}\b")
PASSPORT_RE = re.compile(r"\b\d{2}\s?\d{2}\s+\d{6}\b")


def validate_dataset(records: list[dict]) -> list[str]:
    errors: list[str] = []
    seen_ids: set[str] = set()
    seen_text_hashes: dict[str, str] = {}

    for idx, row in enumerate(records):
        doc_id = str(row.get("doc_id", f"row_{idx}"))

        # 1. Uniqueness по doc_id
        if doc_id in seen_ids:
            errors.append(f"[{doc_id}] Дубликат doc_id!")
        seen_ids.add(doc_id)

        # 2. Validity по категории (Schema Drift check)
        cat = row.get("category")
        if cat not in ALLOWED_CATEGORIES:
            errors.append(
                f"[{doc_id}] Недопустимая категория '{cat}' "
                f"(разрешены: {sorted(ALLOWED_CATEGORIES)})"
            )

        # 3. Validity по дате документа
        doc_date = str(row.get("doc_date", ""))
        try:
            datetime.strptime(doc_date, "%Y-%m-%d")
        except ValueError:
            errors.append(f"[{doc_id}] Некорректный формат даты '{doc_date}' (ожидается YYYY-MM-DD)")

        # 4. Completeness и проверка качества OCR текста
        text = str(row.get("text", "")).strip()
        if len(text) < 25:
            errors.append(f"[{doc_id}] Слишком короткий или пустой текст ({len(text)} симв.)")
        else:
            alnum_ratio = sum(ch.isalnum() or ch.isspace() for ch in text) / len(text)
            if alnum_ratio < 0.70:
                errors.append(
                    f"[{doc_id}] Подозрение на битый OCR: доля букв/цифр всего {alnum_ratio:.1%}"
                )

        # 5. Uniqueness по нормализованному тексту (защита от Data Leakage)
        norm_text = re.sub(r"\s+", " ", text.lower())
        text_hash = hashlib.md5(norm_text.encode("utf-8")).hexdigest()
        if text_hash in seen_text_hashes:
            prev_id = seen_text_hashes[text_hash]
            errors.append(f"[{doc_id}] Полный дубликат текста с документом [{prev_id}] (Data Leakage!)")
        seen_text_hashes[text_hash] = doc_id

        # 6. Privacy Gate: проверка на открытый СНИЛС или серию/номер паспорта
        if SNILS_RE.search(text) or PASSPORT_RE.search(text):
            errors.append(f"[{doc_id}] Обнаружены незамаскированные ПДн (СНИЛС/паспорт)!")

    return errors


def main() -> int:
    dataset_path = Path(__file__).parent / "golden_docs_dataset.json"
    data = json.loads(dataset_path.read_text(encoding="utf-8"))
    docs = data["documents"]

    print(f"=== 1. Проверка эталонного набора ({dataset_path.name}, {len(docs)} док.) ===")
    errors = validate_dataset(docs)
    if errors:
        for err in errors:
            print("  [FAIL]", err)
        return 1
    print("  [OK] Все 4 измерения качества (Completeness, Validity, Uniqueness, Privacy) пройдены!")

    print("\n=== 2. Самопроверка валидатора на заведомо испорченных записях ===")
    broken_docs = [
        {
            "doc_id": "bad_01",
            "category": "medcine_typo",  # Опечатка в категории (Schema Drift)
            "doc_date": "2026-99-99",    # Невалидная дата
            "text": "###@@@$$$%%%^^^&&&***((()))___+++",  # Мусор после битого OCR
        },
        {
            "doc_id": "bad_02",
            "category": "gov",
            "doc_date": "2026-02-01",
            "text": "Справка выдана пациенту, СНИЛС 123-456-789 01, паспорт 45 09 123456.",
        },
    ]
    caught = validate_dataset(broken_docs)
    print(f"  Перехвачено ошибок на тестовом мусоре: {len(caught)}")
    for err in caught:
        print(f"    -> {err}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
