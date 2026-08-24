# Секреты в CI/CD пайплайнах

## Чего никогда не делать

```yaml
# НИКОГДА не хардкодить в .gitlab-ci.yml / .github/workflows/
script:
  - aws configure set aws_access_key_id AKIAIOSFODNN7EXAMPLE  # red flag
  - export DB_PASS=mysecretpassword                            # red flag

# НИКОГДА не передавать через build args в Dockerfile
docker build --build-arg DB_PASS=secret .
# build args видны в docker history!

# НИКОГДА не коммитить .env файлы
git add .env  # red flag
```

## GitLab CI — правильная работа с секретами

```yaml
# Секреты задаются в Settings → CI/CD → Variables
# Флаги:
#   Protected: только для protected branches
#   Masked: скрывает значение из логов
#   Expanded: раскрывает переменные внутри значения

deploy:
  script:
    # переменная из Settings (masked, protected)
    - echo "$AWS_SECRET_ACCESS_KEY" | wc -c  # длина, без вывода значения
    - aws s3 sync dist/ s3://my-bucket/
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'   # только protected branch
```

```yaml
# Vault integration через GitLab CI OIDC
deploy:
  id_tokens:
    VAULT_TOKEN:
      aud: https://vault.example.com
  script:
    - export VAULT_ADDR="https://vault.example.com"
    - vault login -method=jwt jwt="$VAULT_TOKEN" role=gitlab-deploy
    - export DB_PASS=$(vault kv get -field=password secret/production/db)
    - ./deploy.sh
```

## GitHub Actions — правильная работа с секретами

```yaml
# Секреты: Settings → Secrets → Actions
# Environment secrets: только для конкретного environment (с approval)

deploy:
  environment: production   # требует approve + использует environment secrets
  steps:
    - name: Deploy
      env:
        DB_PASSWORD: ${{ secrets.DB_PASSWORD }}   # из GitHub secrets
      run: ./deploy.sh
```

```yaml
# OIDC — без статических ключей AWS
deploy:
  permissions:
    id-token: write    # разрешить получение OIDC токена
    contents: read

  steps:
    - uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: arn:aws:iam::123456789:role/github-actions-prod
        aws-region: eu-central-1
        # НЕТ access_key_id / secret_access_key
        # GitHub получает временный токен через OIDC

    - run: aws s3 sync dist/ s3://my-bucket/
```

## Vault Agent — динамические секреты в k8s pipeline

```yaml
# .gitlab-ci.yml — runner в k8s, Vault Agent Injector добавит секреты
deploy-k8s:
  image: bitnami/kubectl
  script:
    # секреты смонтированы как файлы через Vault Agent Injector
    - DB_PASS=$(cat /vault/secrets/db-password)
    - helm upgrade --install myapp ./chart --set db.password="$DB_PASS"
```

```yaml
# Pod spec для runner'а с Vault аннотациями
metadata:
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "gitlab-runner"
    vault.hashicorp.com/agent-inject-secret-db-password: "secret/data/production/db"
    vault.hashicorp.com/agent-inject-template-db-password: |
      {{- with secret "secret/data/production/db" -}}
      {{ .Data.data.password }}
      {{- end }}
```

## Ротация и лучшие практики

```bash
# Обнаружить секреты закоммиченные случайно
git log --all --full-history -S "AKIA"  # AWS keys
git log --all --full-history -S "password"

# gitleaks — сканер в pre-commit и CI
gitleaks detect --source . --verbose
gitleaks detect --log-opts "HEAD~1..HEAD"  # только последний коммит
```

```yaml
# pre-commit hook
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.2
    hooks:
      - id: gitleaks
```

**Правила:**
1. Rotate immediately если секрет попал в git history (даже в приватный репо)
2. Используй OIDC/IRSA вместо статических ключей где возможно
3. Отдельные credentials для каждого pipeline/environment (не shared)
4. TTL: краткосрочные credentials предпочтительнее долгосрочных
5. Masked variables + Protected branches для production секретов
