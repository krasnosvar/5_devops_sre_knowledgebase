# Тестирование в пайплайнах — шпаргалка

Подробности и объяснения — в
[testing_in_ci.md](./01_theory/testing_in_ci.md). ⚠️ — опасная команда
или частая ловушка.

## Пирамида и порядок в пайплайне (fail fast)

| Слой | Время | Что проверяет | Когда запускать |
| :--- | :--- | :--- | :--- |
| Lint / SAST | секунды | стиль, AST, уязвимые паттерны | каждый пуш, параллельно с unit |
| Unit | мс на тест | функции, зависимости замоканы | каждый пуш |
| Integration | минуты | связка с реальной БД/брокером | каждый MR |
| Contract (Pact) | минуты | формат запросов между сервисами | MR обеих сторон |
| E2E | десятки минут | сценарий пользователя в браузере | на review app / перед релизом |
| Load (k6) | минуты | p95, ошибки под нагрузкой | main / перед релизом, выделенный раннер |
| DAST | минуты–часы | атаки на запущенный стенд | на staging |

## Какой инструмент когда

| Задача | Инструмент |
| :--- | :--- |
| Качество кода, coverage, Quality Gate | SonarQube (`sonar-scanner`) |
| SAST | Semgrep, SonarQube, GitLab SAST |
| SCA (CVE в зависимостях) | Trivy, Snyk, Dependabot |
| DAST | OWASP ZAP |
| БД для интеграционных тестов | Testcontainers (нужен Docker API) или `services:` в CI |
| Зависимый сервис без запуска | моки/стабы, Pact |
| Браузерные тесты headless | Playwright, Cypress, Selenium |
| Нагрузка с порогами | k6 (`thresholds`), JMeter |

## Команды

| Задача | Команда |
| :--- | :--- |
| Unit + coverage (Python) | `pytest --cov=src --cov-report=xml --junitxml=report.xml` |
| SonarQube: ждать Quality Gate | `sonar-scanner -Dsonar.qualitygate.wait=true -Dsonar.qualitygate.timeout=300` |
| k6 локально | `k6 run k6-load-test.js` |
| k6 с параметрами | `k6 run -e BASE_URL=https://pr-123.example.com --vus 10 --duration 1m script.js` |
| k6 сводка в JSON | `k6 run --summary-export summary.json script.js` |
| k6 сырые метрики | `k6 run --out json=results.json script.js` |
| Cypress в CI | `npx cypress run --browser chrome` (headless по умолчанию) |
| Playwright шардинг | `npx playwright test --shard=1/5` |

## k6 thresholds

```javascript
export const options = {
  thresholds: {
    http_req_duration: ['p(95)<200'],  // 95% запросов быстрее 200 мс
    http_req_failed: ['rate<0.01'],    // ошибок меньше 1%
  },
};
```

⚠️ При нарушении порога `k6 run` завершается с кодом **99** (не 1) —
пайплайн падает, но в скриптах не проверять `== 1`.

## Отчёты тестов в CI

| CI | Как показать результаты |
| :--- | :--- |
| GitLab | `artifacts: reports: junit: report.xml`, `coverage_report: coverage_format: cobertura` |
| GitHub Actions | `actions/upload-artifact` + action публикации JUnit; coverage — Codecov |

## Review Apps (эфемерные окружения)

| Шаг | GitLab CI |
| :--- | :--- |
| Создать | `environment: name: review/$CI_COMMIT_REF_SLUG`, `url: https://$CI_COMMIT_REF_SLUG.example.com` |
| Удалить при мерже/закрытии | `on_stop: stop_review` + джоба `stop_review` с `action: stop` |
| Страховка | `auto_stop_in: 1 day` |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| Интеграционные тесты падают при параллельных пайплайнах | общая БД → Testcontainers / `services:` на джобу |
| Testcontainers: `Could not find a valid Docker environment` | нет доступа к Docker API (`DOCKER_HOST`, сокет, DinD) |
| E2E идут 45 минут | шардинг по N параллельным джобам (`parallel`/matrix) |
| k6 «скачет» между сборками | шумные соседи, CPU steal → выделенный раннер |
| Quality Gate FAILED | coverage нового кода ниже порога (типично 80%), новые критичные issues |
| Браузер не стартует на раннере | нет headless-режима или нужных библиотек в образе |

## Ловушки

- ⚠️ 100% coverage ≠ нет багов: тест без `assert` тоже покрывает строки.
- ⚠️ Нагрузочный тест на shared-раннере даёт ложные падения.
- Тяжёлые E2E — после дешёвых проверок, не параллельно с ними.

> Проверка: `k6` 2.3 (`run --help`, код выхода 99 при нарушении порога
> проверен прогоном в `grafana/k6`); не проверено: `sonar-scanner`,
> Cypress, Playwright, `pytest-cov` (инструментов нет локально).
