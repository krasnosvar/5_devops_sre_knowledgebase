# CI/CD — теория пайплайнов

## Определения

**CI (Continuous Integration)** — автоматическая проверка каждого изменения кода:
сборка, тесты, линтинг. Цель: обнаружить проблему как можно раньше.

**CD (Continuous Delivery)** — код всегда готов к деплою в production.
Деплой выполняется вручную или по нажатию кнопки.

**CD (Continuous Deployment)** — каждое изменение прошедшее CI автоматически
деплоится в production. Требует высокой зрелости тестирования.

## DORA метрики — как измерять эффективность

| Метрика | Описание | Elite performers |
|---------|----------|-----------------|
| **Deployment Frequency** | Как часто деплоите | Multiple times/day |
| **Lead Time for Changes** | От коммита до production | < 1 час |
| **Change Failure Rate** | % деплоев вызвавших инцидент | < 5% |
| **MTTR** (Mean Time To Restore) | Время восстановления после инцидента | < 1 час |

Книга *Accelerate* (Forsgren, Humble, Kim) доказывает корреляцию этих метрик
с бизнес-результатами.

## Анатомия пайплайна

```
Trigger (push/PR/schedule/manual)
    │
    ▼
┌─────────────────────────────────────────┐
│ Stage 1: Validate                       │
│  - lint (eslint, ruff, hadolint)        │
│  - type check (mypy, tsc)              │
│  - secret scanning (gitleaks)          │
└──────────────┬──────────────────────────┘
               │ fail fast — дальше не идём
               ▼
┌─────────────────────────────────────────┐
│ Stage 2: Test                           │
│  - unit tests (параллельно)            │
│  - integration tests (с БД/кешем)      │
│  - coverage check                      │
└──────────────┬──────────────────────────┘
               ▼
┌─────────────────────────────────────────┐
│ Stage 3: Build                          │
│  - docker build                        │
│  - push to registry                    │
│  - SBOM generation                     │
│  - image scan (trivy)                  │
└──────────────┬──────────────────────────┘
               ▼
┌─────────────────────────────────────────┐
│ Stage 4: Deploy Staging                 │
│  - helm upgrade / argocd sync          │
│  - smoke tests                         │
└──────────────┬──────────────────────────┘
               │ (manual gate для production)
               ▼
┌─────────────────────────────────────────┐
│ Stage 5: Deploy Production              │
│  - canary деплой (10% трафика)         │
│  - metrics baseline (5 мин)            │
│  - full rollout или rollback           │
└─────────────────────────────────────────┘
```

## Trunk-based Development vs Feature Branches

**Trunk-based** — все коммиты в main. Фичи за feature flags.
Меньше merge conflicts, быстрее CI feedback. Требует discipline.

**Feature branches** — долгоживущие ветки. Проще для команд с review процессом.
Risk: merge hell при долгих ветках, drift между ветками.

**Рекомендация:** short-lived branches (< 2 дня) + feature flags в production.

## Артефакты и кэш

```yaml
# GitLab CI: кэш зависимостей (не пересобирать при каждом запуске)
cache:
  key:
    files:
      - requirements.txt         # кэш инвалидируется при изменении файла
  paths:
    - .venv/
  policy: pull-push

# Артефакты (передача между stages, скачивание)
artifacts:
  paths:
    - dist/
    - coverage/
  expire_in: 1 week
  reports:
    coverage_report:
      coverage_format: cobertura
      path: coverage.xml
```

## Secrets в пайплайнах — правильно

```
НИКОГДА: захардкоженные в .gitlab-ci.yml / .github/workflows/
НИКОГДА: в переменных без маскировки
НИКОГДА: в артефактах или логах

ПРАВИЛЬНО:
  - GitLab: Protected variables (только для protected branches)
  - GitHub: Repository secrets + Environment secrets
  - Лучше: OIDC token → получать credentials из Vault/AWS без статических ключей
```

```yaml
# GitHub Actions: OIDC → AWS (без статических ключей)
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::123456789:role/github-actions-role
    aws-region: eu-central-1
    # Нет access_key_id / secret_access_key!
    # GitHub Actions получает временный токен через OIDC
```

## Параллельность в пайплайнах

```yaml
# GitLab CI: параллельный запуск тестов
test:
  parallel: 4                    # запустить 4 копии job
  script:
    - pytest tests/ -k "test_${CI_NODE_INDEX}"   # каждая берёт свой кусок

# или matrix
test:
  parallel:
    matrix:
      - PYTHON_VERSION: ["3.10", "3.11", "3.12"]
        DATABASE: ["postgres", "sqlite"]
```

## Идемпотентный деплой

```bash
# плохо: создаёт ресурс, падает если уже существует
kubectl create deployment myapp --image=myapp:1.0

# хорошо: создаёт или обновляет (идемпотентно)
kubectl apply -f deployment.yaml

# helm: idempotent upgrade
helm upgrade --install myapp ./chart \
  --set image.tag=${CI_COMMIT_SHORT_SHA} \
  --wait --timeout 5m
```
