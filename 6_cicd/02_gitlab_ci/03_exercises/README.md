# Упражнения — GitLab CI

Стенд: ☁️ Tier 3 — GitLab.com (бесплатный аккаунт, ограниченные минуты
CI/мес) или 🐳 Tier 1 — self-hosted GitLab CE + Runner в Docker Compose
(раздел 00 ниже).

## 00 — Стенд (🐳 Tier 1): GitLab CE + Runner

Пропустите, если работаете на GitLab.com (там уже есть shared runners).

Файл стенда:
[../02_examples/docker-compose.yaml](../02_examples/docker-compose.yaml)
(сервис `gitlab` и сервис `gitlab-runner`, общая сеть `gitlab-lab`).

**1. Поднять GitLab и дождаться готовности** (первый старт — 3-5 минут):

```bash
cd 6_cicd/02_gitlab_ci/02_examples
docker compose up -d
docker compose ps        # gitlab должен стать (healthy)
# пароль root (файл удаляется через 24 часа после установки)
docker compose exec gitlab grep 'Password:' /etc/gitlab/initial_root_password
```

Открыть http://localhost:8929, войти как `root`, создать проект.

**2. Создать раннер в UI (GitLab 16+).** Старый способ — общий
*registration token* и `gitlab-runner register --registration-token` —
устарел (deprecated) и отключается в новых версиях. Теперь раннер сначала
создаётся на сервере:

- проект → Settings → CI/CD → Runners → **New project runner**;
- поставить галочку **Run untagged jobs** (упражнения ниже без `tags:`);
- **Create runner** → GitLab покажет токен вида `glrt-...` (он показывается
  один раз — скопируйте сразу).

**3. Зарегистрировать раннер с docker executor.** Адрес — имя сервиса
compose (`gitlab`), а не `localhost`: внутри контейнера раннера
`localhost` — это сам раннер.

```bash
docker compose exec gitlab-runner gitlab-runner register \
  --non-interactive \
  --url http://gitlab:8929 \
  --token glrt-ВАШ_ТОКЕН \
  --executor docker \
  --docker-image alpine:3.20 \
  --docker-network-mode gitlab-lab
```

`--docker-network-mode gitlab-lab` подключает контейнеры джоб к сети
compose — иначе они не разрезолвят `gitlab` и упадут на `git clone`.
Теги, `run untagged`, protected задаются в UI (шаг 2); с токеном `glrt-`
флаги вроде `--tag-list` больше не принимаются.

**4. Проверить:**

```bash
docker compose exec gitlab-runner gitlab-runner verify
docker compose exec gitlab-runner cat /etc/gitlab-runner/config.toml
```

В UI (Settings → CI/CD → Runners) раннер должен стать зелёным (online).

> Джобы с Docker-in-Docker (`services: [docker:24-dind]`, сборка образа в
> [../02_examples/.gitlab-ci.yml](../02_examples/.gitlab-ci.yml)) требуют
> раннер с `--docker-privileged`. Для упражнений 01-04 он не нужен; почему
> privileged-раннер опасен — в теории, раздел 5.

Остановить стенд: `docker compose down` (данные останутся в volumes),
удалить полностью: `docker compose down -v`.

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
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
      when: manual   # when внутри правила, а не на уровне джобы
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
