# 06. Тестирование в пайплайнах

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — команды и шаблоны одним экраном.

## Зачем
Пайплайн ценен ровно настолько, насколько ловит ошибки до прода. Тема о
том, какие тесты и в каком порядке ставить в CI (пирамида, SAST,
интеграционные на Testcontainers, E2E, нагрузка), как бороться с flaky
tests и как проверить сервис сразу после деплоя (smoke).

## Пререквизиты
-  [02_gitlab_ci](../02_gitlab_ci/) или
  [03_github_actions](../03_github_actions/)
  — services в джобах, artifacts с отчётами.
- [1_linux_and_shell](../../1_linux_and_shell/) — bash (`set -euo
  pipefail`, `curl`), чтобы читать smoke-тест.

## Файлы
- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: пирамида, инструменты, k6.
- [01_theory/testing_in_ci.md](./01_theory/testing_in_ci.md) — пирамида
  тестов, SAST/SonarQube, Testcontainers, E2E, нагрузочные тесты,
  вопросы с собеседований.
- [02_examples/](./02_examples/):
  - [smoke-test.sh](./02_examples/smoke-test.sh) — smoke-проверка после
    деплоя: ожидание `/health` с ретраями и счётчик PASS/FAIL;
  - [k6-load-test.js](./02_examples/k6-load-test.js) — нагрузочный тест
    k6 с порогами (`p(95)<500`), `BASE_URL` через `-e`.

Без отдельных упражнений: примеры запускаются против любого HTTP-сервиса
(например, приложения капстоуна
[0_lab_setup/05_capstone_project](../../0_lab_setup/05_capstone_project/)).

## Как проходить
1. Теория.
2. Запустить smoke-тест против локального сервиса:
   `./smoke-test.sh http://localhost:8080`.
3. Запустить k6 (`k6 run -e BASE_URL=http://localhost:8080
   k6-load-test.js`) и посмотреть, как порог валит прогон.

## Когда двигаться дальше
- Можете расставить lint/unit/integration/E2E/smoke по стадиям и
  объяснить, почему E2E не гоняют на каждый коммит.
- Можете объяснить, чем Testcontainers лучше общей тестовой БД.
- Понимаете, как порог k6 превращается в ненулевой код выхода и падение
  джобы.

Дальше: раздел [7_compute_platforms](../../7_compute_platforms/).
