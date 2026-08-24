# GitHub Actions

## Структура workflow

```yaml
# .github/workflows/ci.yaml
name: CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 6 * * 1'    # каждый понедельник в 06:00 UTC
  workflow_dispatch:         # ручной запуск из UI
    inputs:
      environment:
        description: 'Target environment'
        required: true
        default: 'staging'
        type: choice
        options: [staging, production]

env:
  REGISTRY: ghcr.io
  IMAGE: ghcr.io/${{ github.repository }}

jobs:
  lint:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: pip

      - run: pip install ruff mypy
      - run: ruff check .
      - run: mypy src/

  test:
    runs-on: ubuntu-24.04
    needs: lint             # запустить после lint
    strategy:
      matrix:
        python: ['3.10', '3.11', '3.12']
      fail-fast: false      # не прерывать другие матрицы при ошибке

    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: test
          POSTGRES_DB: testdb
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python }}
          cache: pip

      - run: pip install -r requirements-dev.txt

      - run: pytest tests/ -v --cov=src
        env:
          DATABASE_URL: postgresql://postgres:test@localhost/testdb

      - uses: codecov/codecov-action@v4
        with:
          token: ${{ secrets.CODECOV_TOKEN }}

  build:
    runs-on: ubuntu-24.04
    needs: test
    if: github.ref == 'refs/heads/main'
    permissions:
      packages: write        # для push в GHCR
      contents: read

    steps:
      - uses: actions/checkout@v4

      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}   # автоматический токен

      - uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            ${{ env.IMAGE }}:${{ github.sha }}
            ${{ env.IMAGE }}:latest
          cache-from: type=gha    # кэш в GitHub Actions cache
          cache-to: type=gha,mode=max

  deploy:
    runs-on: ubuntu-24.04
    needs: build
    environment: production    # требует подтверждения в UI
    permissions:
      id-token: write          # для OIDC

    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/github-actions
          aws-region: eu-central-1
          # Без access_key! Токен через OIDC

      - run: |
          aws eks update-kubeconfig --name my-cluster
          helm upgrade --install myapp ./chart \
            --set image.tag=${{ github.sha }} \
            --wait
```

## Reusable workflows — переиспользование

```yaml
# .github/workflows/deploy-template.yaml (вызываемый)
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
      image-tag:
        required: true
        type: string
    secrets:
      KUBECONFIG:
        required: true

jobs:
  deploy:
    runs-on: ubuntu-24.04
    steps:
      - run: helm upgrade --install myapp ./chart
          --set image.tag=${{ inputs.image-tag }}
        env:
          KUBECONFIG: ${{ secrets.KUBECONFIG }}
```

```yaml
# Вызов из основного workflow
jobs:
  deploy-staging:
    uses: ./.github/workflows/deploy-template.yaml
    with:
      environment: staging
      image-tag: ${{ github.sha }}
    secrets:
      KUBECONFIG: ${{ secrets.STAGING_KUBECONFIG }}

  deploy-prod:
    uses: ./.github/workflows/deploy-template.yaml
    needs: deploy-staging
    with:
      environment: production
      image-tag: ${{ github.sha }}
    secrets:
      KUBECONFIG: ${{ secrets.PROD_KUBECONFIG }}
```

## Composite Actions — переиспользование шагов

```yaml
# .github/actions/setup-python-env/action.yaml
name: Setup Python Environment
description: Install Python and dependencies with caching

inputs:
  python-version:
    default: '3.12'
  requirements-file:
    default: requirements.txt

runs:
  using: composite
  steps:
    - uses: actions/setup-python@v5
      with:
        python-version: ${{ inputs.python-version }}
        cache: pip
        cache-dependency-path: ${{ inputs.requirements-file }}

    - run: pip install -r ${{ inputs.requirements-file }}
      shell: bash
```

```yaml
# Использование в workflow
steps:
  - uses: ./.github/actions/setup-python-env
    with:
      python-version: '3.12'
```

## Полезные встроенные переменные

```bash
${{ github.sha }}              # SHA коммита
${{ github.ref }}              # refs/heads/main
${{ github.ref_name }}         # main (ветка или тег)
${{ github.actor }}            # login пользователя
${{ github.repository }}       # owner/repo
${{ github.event_name }}       # push, pull_request, schedule, ...
${{ github.run_id }}           # уникальный ID run
${{ secrets.MY_SECRET }}       # секрет
${{ vars.MY_VAR }}             # переменная (не секрет)
${{ env.MY_ENV }}              # env переменная из env: секции
${{ runner.os }}               # Linux, macOS, Windows
```

## Concurrency — предотвратить параллельные деплои

```yaml
concurrency:
  group: deploy-${{ github.ref }}    # одна группа на ветку
  cancel-in-progress: true            # отменить предыдущий если есть новый
```
