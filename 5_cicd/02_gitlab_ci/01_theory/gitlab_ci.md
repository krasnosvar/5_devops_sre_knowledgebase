# GitLab CI/CD

## Структура .gitlab-ci.yml

```yaml
# .gitlab-ci.yml
stages:
  - validate
  - test
  - build
  - deploy-staging
  - deploy-production

variables:
  DOCKER_DRIVER: overlay2
  IMAGE: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA

# Глобальный before_script (выполняется перед каждым job'ом)
default:
  before_script:
    - echo "Pipeline for $CI_COMMIT_REF_NAME"
  interruptible: true       # можно прервать при новом push
  retry:
    max: 2
    when: runner_system_failure

# ── Validate ──────────────────────────────────────────────────────────────────
lint:
  stage: validate
  image: python:3.12-slim
  script:
    - pip install ruff mypy
    - ruff check .
    - mypy src/
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH == "main"'

# ── Test ──────────────────────────────────────────────────────────────────────
test:
  stage: test
  image: python:3.12-slim
  services:
    - postgres:16-alpine    # поднимается рядом с job контейнером
    - redis:7-alpine
  variables:
    POSTGRES_DB: testdb
    POSTGRES_USER: test
    POSTGRES_PASSWORD: test
    DATABASE_URL: postgresql://test:test@postgres/testdb
  script:
    - pip install -r requirements-dev.txt
    - pytest tests/ -v --cov=src --cov-report=xml
  coverage: '/TOTAL.*\s+(\d+%)$/'   # парсить coverage из stdout
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage.xml
    expire_in: 1 week

# ── Build ─────────────────────────────────────────────────────────────────────
build-image:
  stage: build
  image: docker:24
  services:
    - docker:24-dind
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - docker build --cache-from $CI_REGISTRY_IMAGE:latest -t $IMAGE .
    - docker push $IMAGE
    - docker tag $IMAGE $CI_REGISTRY_IMAGE:latest
    - docker push $CI_REGISTRY_IMAGE:latest
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'

# ── Deploy staging ────────────────────────────────────────────────────────────
deploy-staging:
  stage: deploy-staging
  image: bitnami/kubectl:latest
  environment:
    name: staging
    url: https://staging.example.com
  script:
    - kubectl set image deployment/myapp app=$IMAGE -n staging
    - kubectl rollout status deployment/myapp -n staging --timeout=5m
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'

# ── Deploy production ─────────────────────────────────────────────────────────
deploy-production:
  stage: deploy-production
  image: bitnami/kubectl:latest
  environment:
    name: production
    url: https://example.com
  when: manual               # ручной запуск
  allow_failure: false
  script:
    - helm upgrade --install myapp ./chart -n production
      --set image.tag=$CI_COMMIT_SHORT_SHA
      --wait --timeout 10m
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
```

## Встроенные переменные

```bash
$CI_COMMIT_SHA          # полный SHA коммита
$CI_COMMIT_SHORT_SHA    # первые 8 символов SHA
$CI_COMMIT_REF_NAME     # ветка или тег
$CI_COMMIT_BRANCH       # ветка
$CI_PIPELINE_ID         # ID пайплайна
$CI_JOB_ID              # ID job
$CI_PROJECT_PATH        # namespace/project-name
$CI_REGISTRY            # адрес GitLab Container Registry
$CI_REGISTRY_IMAGE      # $CI_REGISTRY/$CI_PROJECT_PATH
$CI_REGISTRY_USER       # логин для registry
$CI_REGISTRY_PASSWORD   # пароль для registry
$CI_ENVIRONMENT_NAME    # имя environment
```

## Rules — когда запускать job

```yaml
# Запустить только на main ветке
rules:
  - if: '$CI_COMMIT_BRANCH == "main"'

# Запустить при MR и на main
rules:
  - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
  - if: '$CI_COMMIT_BRANCH == "main"'

# Запустить если изменился файл
rules:
  - changes:
      - "src/**/*"
      - "tests/**/*"
      - requirements*.txt

# Комбинация: только на main И только если изменился код
rules:
  - if: '$CI_COMMIT_BRANCH == "main"'
    changes:
      - "src/**/*"

# Пропустить если commit message содержит [skip ci]
rules:
  - if: '$CI_COMMIT_MESSAGE =~ /\[skip ci\]/'
    when: never
  - when: always
```

## Cache — кэширование зависимостей

```yaml
# кэш Python venv между job'ами одной ветки
cache:
  key:
    files:
      - requirements.txt
    prefix: $CI_COMMIT_REF_SLUG
  paths:
    - .venv/
  policy: pull-push    # pull-push: скачать + обновить после job'а
                       # pull: только скачать (для read-only)
                       # push: только обновить

# инициализация с кэшем
before_script:
  - python -m venv .venv
  - source .venv/bin/activate
  - pip install -r requirements.txt
```

## Parallel matrix — тестировать несколько версий

```yaml
test:
  parallel:
    matrix:
      - PYTHON_VERSION: ["3.10", "3.11", "3.12"]
        DB: ["postgres", "mysql"]
  image: python:${PYTHON_VERSION}-slim
  services:
    - name: ${DB}:latest
  script:
    - pytest tests/ -x

# Создаст 6 параллельных job'ов: 3 версии * 2 БД
```

## Reusable components — include

```yaml
# .gitlab/ci/build.yaml (общий шаблон)
.build-template:
  image: docker:24
  services: [docker:24-dind]
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY

# Основной .gitlab-ci.yml
include:
  - local: .gitlab/ci/build.yaml
  - project: company/shared-ci-templates
    ref: main
    file: .gitlab/templates/security-scan.yaml

build:
  extends: .build-template
  script:
    - docker build -t $IMAGE .
```

## OIDC — получить credentials без статических ключей

```yaml
# AWS без статических ключей (через OIDC)
deploy-aws:
  image: amazon/aws-cli
  id_tokens:
    AWS_TOKEN:
      aud: sts.amazonaws.com
  script:
    - export $(aws sts assume-role-with-web-identity
        --role-arn arn:aws:iam::123456789:role/gitlab-ci
        --role-session-name gitlab
        --web-identity-token $AWS_TOKEN
        --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]'
        --output text | awk '{print "AWS_ACCESS_KEY_ID="$1" AWS_SECRET_ACCESS_KEY="$2" AWS_SESSION_TOKEN="$3}')
    - aws s3 sync dist/ s3://mybucket/
```
