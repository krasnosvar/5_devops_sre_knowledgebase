# SAST и статический анализ в CI

## Слои статического анализа

```
Code → SAST         — найти уязвимости в коде (SQL injection, hardcoded secrets)
IaC  → Checkov / trivy config (бывший tfsec) — Terraform, k8s манифесты
Deps → Trivy/Grype  — найти CVE в зависимостях
Container → Trivy   — CVE в образе
Docker → hadolint   — ошибки в Dockerfile
k8s → kubesec       — риски в YAML манифестах
```

## Semgrep — SAST для кода

```bash
# установка
pip install semgrep

# сканирование с правилами сообщества
semgrep --config=auto .

# конкретные правила
semgrep --config=p/python --config=p/django .
semgrep --config=p/kubernetes .
semgrep --config=p/secrets .   # поиск секретов

# только критичные
semgrep --config=auto --severity=ERROR .

# в GitLab CI
semgrep-scan:
  image: semgrep/semgrep
  script:
    - semgrep --config=auto --error --json > semgrep-results.json || true
  artifacts:
    reports:
      sast: semgrep-results.json
```

## Checkov — Terraform и IaC

```bash
pip install checkov

# сканировать Terraform
checkov -d ./terraform/ --framework terraform

# сканировать k8s манифесты
checkov -d ./kubernetes/ --framework kubernetes

# Dockerfile
checkov -f Dockerfile --framework dockerfile

# конкретные проверки
checkov -d . --check CKV_AWS_20,CKV_AWS_57   # только S3 публичный доступ
checkov -d . --skip-check CKV_AWS_18          # пропустить конкретную проверку

# вывод в SARIF (для GitLab/GitHub Security)
checkov -d . --output sarif --output-file checkov.sarif
```

## trivy config — Terraform и IaC (бывший tfsec)

tfsec больше не развивается отдельно: его проверки перенесены в Trivy,
и мейнтейнеры рекомендуют переходить на `trivy config` (misconfiguration
scanning). Старые статьи и pipeline с `tfsec .` переводятся почти
один к одному.

```bash
# установка (см. раздел Trivy ниже)
brew install trivy   # macOS

# сканировать Terraform, k8s-манифесты, Dockerfile в каталоге
trivy config .
trivy config --severity HIGH,CRITICAL .
trivy config --format json --output trivy-config.json .
trivy config --exit-code 1 --severity CRITICAL .   # уронить CI

# игнорировать конкретную проверку — комментарий над ресурсом,
# ID берётся из вывода trivy (поле ID у найденной проблемы)
resource "aws_s3_bucket" "logs" {
  # trivy:ignore:<ID проверки>
  bucket = "my-logs"
}
```

## Trivy — CVE в образах и зависимостях

```bash
# CVE в Docker образе
trivy image nginx:latest
trivy image --severity HIGH,CRITICAL nginx:latest
trivy image --exit-code 1 --severity CRITICAL nginx:latest  # fail CI

# CVE в зависимостях (без Docker)
trivy fs .                    # сканировать текущую директорию
trivy fs --scanners vuln .    # только CVE
trivy fs --scanners secret .  # только секреты

# k8s кластер
trivy k8s --report summary cluster

# в GitLab CI
trivy-scan:
  image: aquasec/trivy:latest
  variables:
    TRIVY_NO_PROGRESS: "true"
    TRIVY_CACHE_DIR: ".trivycache/"
  script:
    - trivy image --exit-code 0 --format template
        --template "@/contrib/gitlab.tpl"
        --output gl-container-scanning-report.json
        $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
  artifacts:
    reports:
      container_scanning: gl-container-scanning-report.json
  cache:
    paths:
      - .trivycache/
```

## kubesec — безопасность k8s манифестов

```bash
# онлайн
curl -sSX POST --data-binary @deployment.yaml https://v2.kubesec.io/scan

# локально
docker run -i kubesec/kubesec:latest scan /dev/stdin < deployment.yaml

# оценка 0+ = ok, < 0 = критично
# показывает конкретные риски:
# "securityContext.runAsNonRoot" not set
# "securityContext.readOnlyRootFilesystem" not set
```

## hadolint — Dockerfile linting

```bash
hadolint Dockerfile

# конкретные правила
hadolint --ignore DL3008 Dockerfile   # игнорировать "pin versions in apt"
hadolint --failure-threshold error Dockerfile

# в CI
hadolint-check:
  image: hadolint/hadolint
  script:
    - hadolint --failure-threshold error Dockerfile
```

## Полный security pipeline

```yaml
# .gitlab-ci.yml — security stage
security:
  stage: security
  parallel:
    matrix:
      - TOOL: semgrep
      - TOOL: checkov
      - TOOL: trivy
  script:
    - |
      case $TOOL in
        semgrep)
          semgrep --config=auto --error . ;;
        checkov)
          checkov -d . --framework terraform,kubernetes --compact ;;
        trivy)
          trivy fs --exit-code 1 --severity CRITICAL . ;;
      esac
  allow_failure: true   # не блокировать pipeline (пока)
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH == "main"'
```

**Стратегия внедрения:**
1. Начать с `allow_failure: true` — видеть результаты, не блокировать
2. Через 2-4 недели: убрать CRITICAL CVE и ошибки SAST
3. Переключить на `allow_failure: false` для CRITICAL
4. Постепенно добавлять HIGH