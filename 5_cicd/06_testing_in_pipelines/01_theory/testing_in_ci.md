# Тестирование в CI/CD

## Пирамида тестов в DevOps

```
         ╱╲
        /  \     E2E тесты (медленные, дорогие, нестабильные)
       /────\
      / Integration \ (с реальными зависимостями: БД, брокеры)
     /──────────────\
    /   Unit тесты   \  (быстрые, изолированные, много)
   /──────────────────\
  / Static analysis    \ (lint, typecheck — мгновенно)
 /──────────────────────\
```

Правило: чем выше пирамида — тем дороже тест. Больше unit, меньше E2E.

## Слои в CI пайплайне

```yaml
# GitLab CI — все слои последовательно с fail fast
stages: [static, unit, integration, build, e2e, deploy]

# Static — быстро, дёшево, запускать всегда первым
lint:
  stage: static
  script:
    - ruff check .        # Python linting
    - mypy src/           # type checking
    - hadolint Dockerfile # Dockerfile linting

# Unit — быстро, без внешних зависимостей
unit-test:
  stage: unit
  script:
    - pytest tests/unit/ -x -q --tb=short

# Integration — с реальными зависимостями через services
integration-test:
  stage: integration
  services:
    - postgres:16-alpine
    - redis:7-alpine
  variables:
    POSTGRES_DB: testdb
    POSTGRES_USER: test
    POSTGRES_PASSWORD: test
  script:
    - pytest tests/integration/ -x -q

# E2E — только на main ветке, используют staging
e2e-test:
  stage: e2e
  script:
    - playwright test
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
```

## Testcontainers — реальные зависимости без docker-compose

```python
# Python / pytest
from testcontainers.postgres import PostgresContainer
from testcontainers.redis import RedisContainer
import pytest

@pytest.fixture(scope="session")
def postgres():
    with PostgresContainer("postgres:16-alpine") as pg:
        yield pg.get_connection_url()

@pytest.fixture(scope="session")
def redis():
    with RedisContainer("redis:7-alpine") as r:
        yield f"redis://{r.get_container_host_ip()}:{r.get_exposed_port(6379)}"

def test_user_creation(postgres):
    db = Database(postgres)
    user = db.create_user("alice@example.com")
    assert user.id is not None
```

Testcontainers запускают реальные Docker контейнеры из тестового кода.
Нет необходимости в `services:` в GitLab CI — сам тест поднимает нужные зависимости.

## Coverage

```bash
# Python
pytest tests/ --cov=src --cov-report=xml --cov-fail-under=80

# Go
go test ./... -coverprofile=coverage.out -covermode=atomic
go tool cover -html=coverage.out -o coverage.html

# настроить минимальный порог
# если coverage < 80% — CI падает
```

```yaml
# GitLab CI — coverage badge и отчёт
test:
  script:
    - pytest tests/ --cov=src --cov-report=xml --cov-report=term
  coverage: '/TOTAL.*\s+(\d+%)$/'    # regex для парсинга coverage из stdout
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage.xml
```

## Flaky tests — как бороться

Flaky test — иногда проходит, иногда нет. Главный враг CI.

**Причины:**
- Race conditions в асинхронном коде
- Зависимость от времени (`datetime.now()`)
- Shared state между тестами (глобальные переменные, БД без cleanup)
- Зависимость от порядка запуска тестов

```python
# Обнаружить flaky tests — запустить 10 раз
pytest tests/ --count=10  # плагин pytest-repeat

# Quarantine — пометить нестабильный тест
@pytest.mark.flaky(reruns=3, reruns_delay=1)
def test_sometimes_fails():
    ...

# GitLab CI — retry только если runner fault, не flaky
test:
  retry:
    max: 1
    when: runner_system_failure  # не retry при обычных ошибках тестов
```

## Параллелизация тестов

```yaml
# GitLab CI — разбить тесты на N частей
test:
  parallel: 4
  script:
    - pytest tests/ --splits $CI_NODE_TOTAL --group $CI_NODE_INDEX \
        --splitting-algorithm least_duration  # плагин pytest-split

# GitHub Actions — matrix
test:
  strategy:
    matrix:
      shard: [1, 2, 3, 4]
  steps:
    - run: pytest tests/ --splits 4 --group ${{ matrix.shard }}
```

## Smoke tests после деплоя

```bash
#!/usr/bin/env bash
# smoke-test.sh — базовая проверка после деплоя
set -euo pipefail

BASE_URL="${1:?Usage: $0 <base_url>}"
MAX_RETRIES=10
DELAY=5

echo "Running smoke tests against $BASE_URL"

# Ждать пока сервис поднимется
for i in $(seq 1 $MAX_RETRIES); do
  if curl -sf "$BASE_URL/health" > /dev/null; then
    echo "Service is up"
    break
  fi
  echo "Attempt $i/$MAX_RETRIES, retrying in ${DELAY}s..."
  sleep $DELAY
done

# Базовые проверки
curl -sf "$BASE_URL/health" | jq -e '.status == "ok"'
curl -sf "$BASE_URL/api/version" | jq -e '.version != null'
echo "Smoke tests passed"
```
