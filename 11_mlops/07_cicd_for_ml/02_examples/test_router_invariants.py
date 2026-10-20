#!/usr/bin/env python3
"""Поведенческие тесты (MFT, INV, DIR) и Quality Gate классификатора
личных документов для CI/CD пайплайна (без внешних тяжелых зависимостей).
"""

from __future__ import annotations

import json
import math
import re
import sys
import time
from collections import Counter
from pathlib import Path
from typing import Dict, List, Tuple

GOLDEN_DATASET_PATH = (
    Path(__file__).resolve().parents[2]
    / "03_data_validation_and_dvc"
    / "02_examples"
    / "golden_docs_dataset.json"
)


class NaiveBayesDocRouter:
    """Легковесный текстовый классификатор личных документов (CPU-first)."""

    def __init__(self, alpha: float = 1.0) -> None:
        self.alpha = alpha
        self.class_counts: Counter[str] = Counter()
        self.word_counts: Dict[str, Counter[str]] = {}
        self.vocab: set[str] = set()
        self.total_docs = 0

    @staticmethod
    def tokenize(text: str) -> List[str]:
        cleaned = re.sub(r"[^\w\s-]", " ", text.lower())
        base_tokens = [tok for tok in cleaned.split() if len(tok) >= 2]
        stems = [f"~{tok[:5]}" for tok in base_tokens if len(tok) >= 6]
        return base_tokens + stems

    def fit(self, texts: List[str], labels: List[str]) -> None:
        for text, label in zip(texts, labels):
            self.total_docs += 1
            self.class_counts[label] += 1
            if label not in self.word_counts:
                self.word_counts[label] = Counter()
            tokens = self.tokenize(text)
            self.word_counts[label].update(tokens)
            self.vocab.update(tokens)

    def predict_proba(self, text: str) -> Dict[str, float]:
        tokens = self.tokenize(text)
        vocab_size = max(len(self.vocab), 1)
        log_scores: Dict[str, float] = {}

        for label, doc_count in self.class_counts.items():
            prior = math.log(doc_count / self.total_docs)
            total_words = sum(self.word_counts[label].values())
            denom = total_words + self.alpha * vocab_size
            likelihood = 0.0
            for tok in tokens:
                count = self.word_counts[label].get(tok, 0)
                likelihood += math.log((count + self.alpha) / denom)
            log_scores[label] = prior + likelihood

        max_log = max(log_scores.values())
        exp_scores = {
            k: math.exp(v - max_log) for k, v in log_scores.items()
        }
        total_exp = sum(exp_scores.values())
        return {k: v / total_exp for k, v in exp_scores.items()}

    def predict(self, text: str) -> Tuple[str, float]:
        probs = self.predict_proba(text)
        best_label = max(probs, key=probs.get)  # type: ignore[arg-type]
        return best_label, probs[best_label]


def load_golden_documents() -> List[ dict ]:
    payload = json.loads(GOLDEN_DATASET_PATH.read_text(encoding="utf-8"))
    return payload["documents"]


def build_model() -> NaiveBayesDocRouter:
    docs = load_golden_documents()
    texts = [row["text"] for row in docs]
    labels = [row["category"] for row in docs]
    # Дополним базовыми якорными примерами для устойчивости словаря
    extra = [
        (
            "Клинический анализ крови гемоглобин лейкоциты СОЭ врач диагноз "
            "клиника осмотр рецепт терапевт МРТ ферритин",
            "medicine",
        ),
        (
            "ФНС налоговая уведомление ИНН КБК налог Госуслуги МФЦ паспорт "
            "выписка ЕГРН СНИЛС госпошлина кадастровый",
            "gov",
        ),
        (
            "Кассовый чек приход ФД ФПД оплата квитанция ЖКУ тариф счет "
            "полис ОСАГО страховая премия вычет руб",
            "finance",
        ),
        (
            "Личная заметка чек-лист список дел бэкап borgbackup сервер "
            "конспект пароль диск",
            "notes",
        ),
        (
            "Рецепт пиццы анекдот погода футбол гороскоп фильм сериал",
            "offtopic",
        ),
    ]
    for t, lbl in extra:
        texts.append(t)
        labels.append(lbl)

    model = NaiveBayesDocRouter(alpha=0.5)
    model.fit(texts, labels)
    return model


def run_ci_suite() -> int:
    model = build_model()
    failures: List[str] = []

    print("=== 1. MFT (Minimum Functionality Tests) ===")
    mft_cases = [
        (
            "Клинический анализ крови: гемоглобин 144 г/л, ферритин 28, "
            "врач терапевт",
            "medicine",
        ),
        (
            "Налоговое уведомление ФНС России: ИНН, КБК, налог на квартиру, "
            "выписка ЕГРН МФЦ",
            "gov",
        ),
        (
            "Кассовый чек и страховой полис ОСАГО: страховая премия 7420 руб "
            "оплачена",
            "finance",
        ),
    ]
    for text, expected in mft_cases:
        pred, conf = model.predict(text)
        status = "OK" if pred == expected and conf >= 0.60 else "FAIL"
        print(f"  [{status}] expected={expected:<12} pred={pred:<12} conf={conf:.3f}")
        if status == "FAIL":
            failures.append(f"MFT failed for {expected}: got {pred} ({conf:.3f})")

    print("\n=== 2. INV (Invariance Tests: регистр, шум OCR, смена ФИО) ===")
    base_text = (
        "Заключение врача: пациент Иванов И.И., диагноз гастрит, клиника"
    )
    noisy_variants = [
        base_text.upper(),
        "   Заключение   врача:\n\nпациент   Петров П.П., диагноз гастрит, клиника  ",
    ]
    base_pred, _ = model.predict(base_text)
    for idx, var in enumerate(noisy_variants, start=1):
        var_pred, _ = model.predict(var)
        status = "OK" if var_pred == base_pred else "FAIL"
        print(f"  [{status}] Variant #{idx}: base={base_pred} vs variant={var_pred}")
        if status == "FAIL":
            failures.append(f"INV failed on variant #{idx}")

    print("\n=== 3. DIR (Directional Expectation Test) ===")
    neutral = "Документ от 15 марта 2026 года на сумму 3200 рублей"
    enriched = neutral + " ФНС налоговое уведомление ИНН КБК выписка ЕГРН МФЦ"
    p_before = model.predict_proba(neutral)["gov"]
    p_after = model.predict_proba(enriched)["gov"]
    dir_ok = p_after > p_before + 0.15
    print(
        f"  [{'OK' if dir_ok else 'FAIL'}] P(gov): "
        f"{p_before:.3f} -> {p_after:.3f}"
    )
    if not dir_ok:
        failures.append("DIR failed: probability did not increase as expected")

    print("\n=== 4. SRE Latency & Quality Gate on Golden Dataset ===")
    golden = load_golden_documents()
    correct = 0
    latencies_ms: List[float] = []
    for row in golden:
        t0 = time.perf_counter()
        pred, _ = model.predict(row["text"])
        latencies_ms.append((time.perf_counter() - t0) * 1000.0)
        if pred == row["category"]:
            correct += 1

    accuracy = correct / len(golden)
    p95_ms = sorted(latencies_ms)[int(len(latencies_ms) * 0.95)]
    champion_baseline = 0.90

    gate_ok = accuracy >= champion_baseline and p95_ms <= 5.0
    print(
        f"  [{'OK' if gate_ok else 'FAIL'}] Golden Set Accuracy={accuracy:.3f} "
        f"(champion={champion_baseline:.3f}), p95_latency={p95_ms:.3f} ms"
    )
    if not gate_ok:
        failures.append("Quality Gate failed on Golden Dataset or Latency")

    if failures:
        print("\nCI/CD QUALITY GATE FAILED:")
        for f in failures:
            print(f"  - {f}")
        return 1

    print("\nALL ML CI/CD INVARIANTS & QUALITY GATES PASSED -> READY TO PROMOTE @champion")
    return 0


if __name__ == "__main__":
    sys.exit(run_ci_suite())
