# Ответы — GitHub Actions

Файлы ответа:
- [ci-answer.yaml](./ci-answer.yaml) — упражнения 01, 02, 04 и вызов
  reusable workflow из 03;
- [deploy.yaml](./deploy.yaml) — reusable workflow (упражнение 03);
- [aws-trust-policy.json](./aws-trust-policy.json) — Trust Policy роли
  для OIDC (упражнение 04).

Все команды — в клоне вашего публичного репозитория на GitHub.

## Упражнение 01 — Hello World workflow

```bash
mkdir -p .github/workflows
# hello.yaml — из условия, но checkout с fetch-depth: 0 (см. ci-answer.yaml)
git add .github/workflows/hello.yaml
git commit -m "hello workflow"
git push origin main
gh run watch          # или вкладка Actions в UI
```

Ожидаемый вывод (примерно так, шаг Show commit info):

```text
Commit: 3f2c1a9e...
Author: your-login
Branch: main
3f2c1a9 hello workflow
8d01b2c initial commit
```

Почему так: `actions/checkout` по умолчанию делает shallow clone
(`fetch-depth: 1`), и `git log --oneline -5` из условия показал бы
только один коммит. `fetch-depth: 0` скачивает всю историю.

## Упражнение 02 — Matrix strategy

```bash
mkdir -p tests
printf 'def test_ok():\n    assert 1 + 1 == 2\n' > tests/test_smoke.py
# джоба test-matrix из ci-answer.yaml вместо TODO
git add tests .github/workflows
git commit -m "matrix"
git push origin main
```

Ожидаемый вывод (примерно так, в UI — 6 джоб):

```text
test-matrix (ubuntu-latest, 3.11)   ✓
test-matrix (ubuntu-latest, 3.12)   ✓
test-matrix (macos-latest, 3.11)    ✓
...
test-matrix (windows-latest, 3.12)  ✓
```

Почему так: матрица — декартово произведение `os × python` (3 × 2 = 6).
`fail-fast: false` не отменяет остальные джобы, если упала одна — видно
все несовместимые сочетания сразу. Тесты запускаются через
`python -m pytest`, чтобы на всех ОС взять pytest из нужного Python.

## Упражнение 03 — Reusable workflow

```bash
cp deploy.yaml .github/workflows/deploy.yaml   # файл из ответов
# в ci.yaml — джоба deploy-staging с uses: ./.github/workflows/deploy.yaml
gh secret set STAGING_KUBECONFIG < ~/.kube/config-staging
git add .github/workflows
git commit -m "reusable deploy"
git push origin main
```

Ожидаемый вывод (примерно так):

```text
deploy-staging / deploy
deployment.apps/myapp image updated
deployment "myapp" successfully rolled out
```

Почему так: `workflow_call` делает workflow вызываемым; входы и секреты
передаются явно (`with:`/`secrets:`), автоматически секреты вызывающего
workflow не наследуются (если не указать `secrets: inherit`). Без
кластера джоба упадёт на `kubectl` — механику вызова видно и так.

## Упражнение 04 — OIDC без статических credentials

Подставить свой `ACCOUNT_ID` и `ORG/REPO` в `aws-trust-policy.json`, затем:

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com
aws iam create-role --role-name github-actions-role \
  --assume-role-policy-document file://aws-trust-policy.json
gh secret set AWS_ROLE_ARN --body \
  "arn:aws:iam::ACCOUNT_ID:role/github-actions-role"
# в репозитории создать Environment production (Settings → Environments)
git commit --allow-empty -m "oidc test" && git push origin main
```

Ожидаемый вывод (примерно так, шаг Verify identity):

```text
{
    "UserId": "AROA...:GitHubActions",
    "Account": "123456789012",
    "Arn": "arn:aws:sts::123456789012:assumed-role/github-actions-role/GitHubActions"
}
```

Убрать за собой:

```bash
aws iam delete-role --role-name github-actions-role
aws iam delete-open-id-connect-provider --open-id-connect-provider-arn \
  arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com
```

Почему так: без `permissions: id-token: write` джоба не получит JWT, а
явный блок `permissions` обнуляет остальные права — поэтому нужен и
`contents: read`. Джоба с `environment: production` получает claim
`sub = repo:ORG/REPO:environment:production`, а не `...:ref:refs/heads/main`
— Trust Policy должна проверять именно его, иначе `AssumeRoleWithWebIdentity`
вернёт `Not authorized`. (Старые версии AWS CLI требуют ещё
`--thumbprint-list` при создании провайдера.)
