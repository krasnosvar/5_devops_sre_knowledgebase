# Ответы к упражнениям: CI/CD для ML и Quality Gates

## Упражнение 1 — Прогон поведенческих тестов (MFT, INV, DIR)

Команда:
```bash
./11_mlops/07_cicd_for_ml/02_examples/test_router_invariants.py
echo "Exit code: $?"
```

Ожидаемый вывод (приблизительно):
```text
=== 1. MFT (Minimum Functionality Tests) ===
  [OK] expected=medicine     pred=medicine     conf=1.000
  [OK] expected=gov          pred=gov          conf=1.000
  [OK] expected=finance      pred=finance      conf=1.000

=== 2. INV (Invariance Tests: регистр, шум OCR, смена ФИО) ===
  [OK] Variant #1: base=medicine vs variant=medicine
  [OK] Variant #2: base=medicine vs variant=medicine

=== 3. DIR (Directional Expectation Test) ===
  [OK] P(gov): 0.661 -> 1.000

=== 4. SRE Latency & Quality Gate on Golden Dataset ===
  [OK] Golden Set Accuracy=1.000 (champion=0.900), p95_latency=0.037 ms

ALL ML CI/CD INVARIANTS & QUALITY GATES PASSED -> READY TO PROMOTE @champion
Exit code: 0
```

**Почему так:** скрипт последовательно проверяет якорные кейсы (`MFT`),
устойчивость к шуму и смене ФИО (`INV`), монотонность вероятности при
добавлении маркеров ФНС (`DIR`) и финальный гейт точности и латентности
на `golden_docs_dataset.json`.

---

## Упражнение 2 — Проверка блокировки сломанного токенизатора в CI

Команда (однострочник, моделирующий отсутствие `.lower()` на `Variant #1`
в верхнем регистре):
```bash
python3 -c '
import sys
sys.path.insert(0, "11_mlops/07_cicd_for_ml/02_examples")
import test_router_invariants as t

model = t.build_model()
# Сломаем нормализацию регистра в токенизаторе:
model.tokenize = lambda text: [w for w in text.split() if len(w) >= 2]
base = "Заключение врача: пациент Иванов И.И., диагноз гастрит, клиника"
print("Base pred:", model.predict(base))
print("UPPER pred:", model.predict(base.upper()))
'
```

Ожидаемый вывод:
```text
Base pred: ('medicine', 0.996...)
UPPER pred: ('medicine', 0.300...)
```

**Почему так:** когда слова в `UPPERCASE` перестают попадать в словарь
обученной модели, все токены становятся неизвестными (`OOV`), и модель
скатывается к априорному распределению классов (`prior`), теряя
уверенность. Именно для отлова таких тихих деградаций предобработки в
CI-пайплайн включают тесты инвариантности (`INV`).
