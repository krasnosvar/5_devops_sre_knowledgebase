# SAST и статический анализ в CI — шпаргалка

Подробности и объяснения — в
[01_theory/sast_in_ci.md](./01_theory/sast_in_ci.md).
⚠️ — опасная команда или частая ловушка.

## Какой сканер на какой слой

| Слой | Инструмент | Команда-минимум |
| :--- | :--- | :--- |
| Код приложения | Semgrep | `semgrep scan --config=auto .` |
| Секреты в репо | gitleaks | `gitleaks git -v .` |
| Terraform / k8s / Dockerfile (misconfig) | trivy config (бывший tfsec), Checkov | `trivy config .` / `checkov -d .` |
| Зависимости (CVE) | Trivy, Grype | `trivy fs --scanners vuln .` |
| Образ | Trivy | `trivy image $IMAGE` |
| Dockerfile (стиль, пиннинг) | hadolint | `hadolint Dockerfile` |
| k8s YAML (риск-скор) | kubesec | `kubesec scan deploy.yaml` |

## Semgrep

| Задача | Команда |
| :--- | :--- |
| Правила сообщества (авто) | `semgrep scan --config=auto .` |
| Наборы правил | `--config=p/python --config=p/secrets --config=p/kubernetes` |
| Только ERROR | `--severity=ERROR` |
| Ненулевой код при находках | `--error` |
| Отчёт для GitLab SAST | `semgrep scan --config=auto --gitlab-sast -o gl-sast-report.json` |
| SARIF (GitHub code scanning) | `semgrep scan --config=auto --sarif -o semgrep.sarif` |
| Только новое относительно main | `semgrep scan --config=auto --baseline-commit=origin/main` |
| Исключить каталог | `--exclude=tests` (или `.semgrepignore`) |
| Подавить строку | комментарий `# nosemgrep: <rule-id>` |

## trivy config (IaC)

| Задача | Команда |
| :--- | :--- |
| Скан каталога | `trivy config .` |
| Порог и падение CI | `trivy config --severity HIGH,CRITICAL --exit-code 1 .` |
| Terraform с переменными | `trivy config --tf-vars prod.tfvars .` |
| Helm-чарт с values | `trivy config --helm-values values-prod.yaml ./chart` |
| Отчёт | `--format json -o trivy-config.json` / `--format sarif -o trivy.sarif` |
| Подавить в Terraform | `# trivy:ignore:AVD-AWS-0107` строкой над ресурсом |

## Checkov

| Задача | Команда |
| :--- | :--- |
| Terraform / k8s / Dockerfile | `checkov -d ./tf --framework terraform`<br>`checkov -d ./k8s --framework kubernetes`<br>`checkov -f Dockerfile --framework dockerfile` |
| Только / кроме проверок | `--check CKV_AWS_20,CKV_AWS_57` / `--skip-check CKV_AWS_18` |
| Компактно, без passed | `--compact --quiet` |
| SARIF в каталог | `-o sarif --output-file-path .` (файл `results_sarif.sarif`) |
| Не падать / падать от уровня | `--soft-fail` / `--hard-fail-on HIGH` |
| Baseline: только новые | `--create-baseline`, затем `--baseline .checkov.baseline` |
| Подавить в коде | `# checkov:skip=CKV_AWS_18:причина` внутри ресурса |

## hadolint и kubesec

| Задача | Команда |
| :--- | :--- |
| Линт Dockerfile | `hadolint Dockerfile` |
| Порог падения | `hadolint --failure-threshold error Dockerfile` |
| Игнор правила | `hadolint --ignore DL3008 Dockerfile` или `# hadolint ignore=DL3008` |
| Только доверенные registry | `hadolint --trusted-registry docker.io --trusted-registry ghcr.io Dockerfile` |
| kubesec локально | `docker run -i kubesec/kubesec:v2 scan /dev/stdin < deploy.yaml` (score < 0 — критично) |

## GitLab CI: шаблоны отчётов

| Сканер | `artifacts:reports:` | Как получить файл |
| :--- | :--- | :--- |
| Semgrep | `sast: gl-sast-report.json` | `--gitlab-sast -o gl-sast-report.json` |
| Trivy image | `container_scanning: gl-container-scanning-report.json` | `--format template --template "@/contrib/gitlab.tpl"` (в образе `aquasec/trivy`) |
| gitleaks | `secret_detection: gl-secret-detection-report.json` | GitLab-шаблон Secret-Detection |

```yaml
trivy-scan:
  image: {name: aquasec/trivy:0.66.0, entrypoint: [""]}
  variables: {TRIVY_NO_PROGRESS: "true", TRIVY_CACHE_DIR: .trivycache/}
  script:
    - trivy image --exit-code 1 --severity CRITICAL --ignore-unfixed
        "$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA"
  cache: {paths: [.trivycache/]}
```

## Внедрение без боли

| Шаг | Как |
| :--- | :--- |
| 1. Видимость | `allow_failure: true`, отчёты в MR |
| 2. Разбор | baseline / ignore-файлы с комментарием-причиной |
| 3. Блокировка CRITICAL | `--exit-code 1 --severity CRITICAL`, `allow_failure: false` |
| 4. Расширение | добавить HIGH, `--baseline-commit` для diff-скана |

## Ловушки

| ⚠️ | Суть |
| :--- | :--- |
| `\|\| true` после сканера | CI зелёный при любых находках — использовать `allow_failure` |
| `semgrep --json` как `sast`-отчёт | не формат GitLab; нужен `--gitlab-sast` |
| `tfsec` в новых pipeline | развитие прекращено, заменять на `trivy config` |
| `trivy conf`, `--security-checks` | старые формы; сейчас `trivy config`, `--scanners` |
| Образ `:latest` у сканера | меняется молча — пиннить версию |
| Скан всего репо на каждом коммите | долго; `--baseline-commit`, кэш БД, параллельные jobs |

> Проверка: `semgrep` 1.140.0, `checkov` 3.2.470 (прогон с
> `--output-file-path`), `trivy` 0.66.0 (`config` + `trivy:ignore` на
> Terraform, `/contrib/gitlab.tpl` в образе), `hadolint` v2.14.0 —
> в Docker; не проверено: kubesec, загрузка отчётов в GitLab.
