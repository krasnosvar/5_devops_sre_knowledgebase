# Ответы к упражнениям: AI DevSecOps — Безопасность ML и LLM

## Упражнение 1 — Сканирование ПДн, Prompt Injection и Pickle-файлов

Команда:
```bash
./11_mlops/11_ml_and_llm_security/02_examples/pii_and_security_scanner.py
```

Ожидаемый вывод (приблизительно):
```text
=== 1. Тест обратимой псевдонимизации ПДн РФ (Presidio-style) ===
  Оригинал : Выписка МФЦ: заявитель Иванов И.И., паспорт 4510 123456, СНИЛС 123-456-789 00, ИНН 770123456789, тел. +7 (999) 123-45-67, почта ivanov@example.ru.
  Маскиров.: Выписка МФЦ: заявитель Иванов И.И., <RU_PASSPORT_1>, СНИЛС <RU_SNILS_1>, ИНН <RU_INN_1>, тел. <PHONE_1>, почта <EMAIL_1>.
...
=== 3. Статический анализ файлов моделей (ModelScan / Fickling) ===
  Чистый словарь данных: safe=True, issues=[]
  Вредоносный .pkl файл: safe=False
    - [CRITICAL] pos=0: GLOBAL import from dangerous module 'posix system'
    - [CRITICAL] pos=22: REDUCE opcode detected (callable execution)

ALL AI DEVSECOPS CHECKS PASSED SUCCESSFULLY
```

**Почему так:** сканер разбирает поток байтов через `pickletools.genops()`
без вызова `pickle.loads()`, поэтому вредоносный пейлоад детектируется
безопасно на этапе CI/CD.

---

## Упражнение 2 — Дизассемблирование Pickle через `pickletools`

Команда:
```bash
python3 -c '
import pickle, pickletools
data = pickle.dumps({"a": 1})
pickletools.dis(data)
'
```

Ожидаемый вывод:
```text
    0: \x80 PROTO      4
    2: \x95 FRAME      10
   11: }    EMPTY_DICT
   12: \x94 MEMOIZE    (as 0)
   13: \x8c SHORT_BINUNICODE 'a'
   16: \x94 MEMOIZE    (as 1)
   17: K    BININT1    1
   19: s    SETITEM
   20: .    STOP
highest protocol among opcodes = 4
```

**Почему так:** для примитивных структур данных (словарей, списков,
чисел и строк) используются декларативные опкоды построения
(`EMPTY_DICT`, `SHORT_BINUNICODE`, `BININT1`, `SETITEM`), которые не
вызывают функции Python. Опкоды `GLOBAL` / `STACK_GLOBAL` и `REDUCE`
появляются только при сериализации произвольных объектов/функций —
именно по этому признаку работает флаг `torch.load(..., weights_only=True)`
и сканеры `ModelScan` / `Fickling`.
