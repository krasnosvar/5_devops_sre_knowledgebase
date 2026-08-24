# Упражнения — GitLab CI

Стенд: ☁️ Tier 3 — GitLab.com (бесплатный аккаунт, 400 мин CI/мес)
или 🐳 Tier 1 — self-hosted GitLab CE через Docker:

```bash
# Self-hosted GitLab (требует 4+ GB RAM)
docker run -d -p 8929:80 \
  -v gitlab_config:/etc/gitlab \
  -v gitlab_data:/var/opt/gitlab \
  gitlab/gitlab-ce:latest
```

## 01 — Первый pipeline

**Задача:** Создать репозиторий и добавить `.gitlab-ci.yml` с тремя stages.

```yaml
stages: [lint, test, build]

lint:
  stage: lint
  image: alpine
  script:
    - echo "Running linter..."
    - test -f README.md || (echo "README.md missing!" && exit 1)

test:
  stage: test
  image: python:3.12-slim
  script:
    - python -m pytest --version || pip install pytest
    - echo "Tests passed"

build:
  stage: build
  image: alpine
  script:
    - echo "Building app..."
    - mkdir -p dist && echo "VERSION=1.0.0" > dist/version.txt
  artifacts:
    paths: [dist/]
    expire_in: 1 week
```

## 02 — Rules — условный запуск

**Задача:** Изменить pipeline так чтобы:
- lint и test — на всех MR и main ветке
- build — только на main ветке
- deploy — только вручную на main ветке

```yaml
build:
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'

deploy:
  when: manual
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
```

## 03 — Cache зависимостей

**Задача:** Добавить кэш pip зависимостей между запусками.
Замерить время до и после добавления кэша.

```yaml
test:
  cache:
    key:
      files: [requirements.txt]
    paths: [.venv/]
  before_script:
    - python -m venv .venv
    - source .venv/bin/activate
    - pip install -r requirements.txt
  script:
    - pytest tests/
```

## 04 — Matrix builds

**Задача:** Запустить тесты на Python 3.10, 3.11, 3.12 параллельно.

```yaml
test:
  parallel:
    matrix:
      - PYTHON_VERSION: ["3.10", "3.11", "3.12"]
  image: python:${PYTHON_VERSION}-slim
  script:
    - python --version
    - pip install pytest
    - pytest tests/ || echo "Tests for Python $PYTHON_VERSION"
```
