# Упражнения — GitHub Actions

Стенд: ☁️ Tier 3 — GitHub.com (бесплатно для public repos, 2000 мин/мес для private)

## 01 — Hello World workflow

**Задача:** Создать `.github/workflows/hello.yaml` который:
- Запускается при каждом push в main
- Печатает информацию о коммите
- Запускает базовые проверки

```yaml
name: Hello World

on:
  push:
    branches: [main]

jobs:
  greet:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Show commit info
        run: |
          echo "Commit: ${{ github.sha }}"
          echo "Author: ${{ github.actor }}"
          echo "Branch: ${{ github.ref_name }}"
          git log --oneline -5
```

## 02 — Matrix strategy

**Задача:** Написать workflow который тестирует код на 3 ОС и 2 версиях Python.

```yaml
jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        python: ["3.11", "3.12"]
      fail-fast: false
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python }}
      - run: python --version
      # TODO: добавить реальные тесты
```

## 03 — Reusable workflow

**Задача:** Вынести деплой в reusable workflow `.github/workflows/deploy.yaml`.

```yaml
# .github/workflows/deploy.yaml
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
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    steps:
      - run: echo "Deploying ${{ inputs.image-tag }} to ${{ inputs.environment }}"
      # TODO: добавить реальный kubectl apply
```

```yaml
# .github/workflows/ci.yaml — вызвать reusable workflow
jobs:
  deploy-staging:
    uses: ./.github/workflows/deploy.yaml
    with:
      environment: staging
      image-tag: ${{ github.sha }}
    secrets:
      KUBECONFIG: ${{ secrets.STAGING_KUBECONFIG }}
```

## 04 — OIDC без статических credentials

**Задача:** Настроить workflow который получает AWS credentials через OIDC (без access_key_id).

```yaml
jobs:
  deploy:
    permissions:
      id-token: write   # нужно для OIDC
      contents: read
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::ACCOUNT:role/github-actions-role
          aws-region: eu-central-1
      - run: aws sts get-caller-identity
```

Создать IAM Role в AWS с Trust Policy для GitHub OIDC.
Документация: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services
