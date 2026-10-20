# Безопасность образов — шпаргалка

Подробности и объяснения — в
[01_theory/image_security.md](./01_theory/image_security.md).
⚠️ — опасная команда или частая ловушка.

## Базовый образ: что выбрать

| Образ | Shell / пакетный менеджер | Когда |
| :--- | :--- | :--- |
| `scratch` | нет / нет | статический бинарник (Go с `CGO_ENABLED=0`) |
| `gcr.io/distroless/static-debian12` | нет / нет | статический бинарник + CA-сертификаты, tzdata, `/etc/passwd` |
| `gcr.io/distroless/python3-debian12`, `.../nodejs*` | нет / нет | интерпретируемые языки без shell |
| `alpine:3.x` | busybox / `apk` | маленький, но musl (возможны отличия от glibc) |
| `*-slim` (debian) | bash / `apt` | компромисс: glibc, привычные инструменты |

## Trivy: скан образа

| Задача | Команда |
| :--- | :--- |
| Скан образа | `trivy image nginx:1.27` |
| Только HIGH/CRITICAL | `trivy image --severity HIGH,CRITICAL nginx:1.27` |
| Уронить CI на CRITICAL | `trivy image --exit-code 1 --severity CRITICAL nginx:1.27` |
| Скрыть CVE без фикса | `trivy image --ignore-unfixed nginx:1.27` |
| Что сканировать | `--scanners vuln,secret,misconfig,license` (по умолчанию `vuln,secret`) |
| Образ из tar (без registry) | `docker save app:1 -o app.tar && trivy image --input app.tar` |
| Конкретная платформа | `trivy image --platform linux/arm64 nginx:1.27` |
| Только ОС-пакеты / только библиотеки | `--pkg-types os` / `--pkg-types library` |
| JSON / SARIF / таблица | `--format json -o r.json` / `--format sarif -o r.sarif` / `--format table` |
| SBOM из образа | `trivy image --format cyclonedx -o sbom.cdx.json app:1` |
| Скан готового SBOM | `trivy sbom sbom.cdx.json` |
| Список игнора | `.trivyignore` (по одному CVE в строке) или `--ignorefile` |
| Показать подавленные | `--show-suppressed` |
| Очистить кэш / БД | `trivy clean --all` |

```bash
# только CRITICAL из JSON-отчёта
trivy image -f json -q nginx:1.27 \
  | jq '.Results[].Vulnerabilities[]? | select(.Severity=="CRITICAL")
        | {VulnerabilityID, PkgName, InstalledVersion, FixedVersion}'
```

## Grype и Syft

| Задача | Команда |
| :--- | :--- |
| Скан образа | `grype nginx:1.27` |
| Каталог / SBOM | `grype dir:.` / `grype sbom:./sbom.json` |
| Уронить CI | `grype nginx:1.27 --fail-on critical` |
| Только с доступным фиксом | `grype nginx:1.27 --only-fixed` |
| Формат | `grype nginx:1.27 -o json` / `-o sarif` / `-o table` |
| SBOM | `syft nginx:1.27 -o cyclonedx-json > sbom.json` (или `-o spdx-json`) |

## Cosign: подпись и проверка

| Задача | Команда |
| :--- | :--- |
| Ключевая пара | `cosign generate-key-pair` (`cosign.key`, `cosign.pub`) |
| Подписать ключом | `cosign sign --key cosign.key registry/app@sha256:...` |
| Подписать keyless (CI с OIDC) | `cosign sign --yes registry/app@sha256:...` |
| Проверить ключом | `cosign verify --key cosign.pub registry/app:1.0` |
| Проверить keyless (GitHub Actions) | `cosign verify registry/app:1.0 --certificate-identity=https://github.com/org/app/.github/workflows/ci.yaml@refs/heads/main --certificate-oidc-issuer=https://token.actions.githubusercontent.com` |
| Identity по шаблону | `--certificate-identity-regexp='^https://github.com/org/'` |
| Что привязано к образу | `cosign tree registry/app:1.0` |
| Digest образа | `crane digest registry/app:1.0` или `docker buildx imagetools inspect registry/app:1.0` |

⚠️ Подписывать по digest, не по тегу: тег можно перезаписать.
⚠️ Keyless `--certificate-identity` для GitHub — URL workflow с ref,
а не e-mail; issuer для GitLab — URL инстанса (`https://gitlab.com`).

## Kyverno: только подписанные образы

```yaml
verifyImages:
  - imageReferences: ["ghcr.io/org/*"]
    failureAction: Enforce        # Kyverno 1.13+
    attestors:
      - entries:
          - keyless:
              subject: "https://github.com/org/app/.github/workflows/ci.yaml@refs/heads/main"
              issuer: "https://token.actions.githubusercontent.com"
```

## Registry (ECR)

| Задача | Команда |
| :--- | :--- |
| Неизменяемые теги | `aws ecr put-image-tag-mutability --repository-name app --image-tag-mutability IMMUTABLE` |
| Скан при push | `aws ecr put-image-scanning-configuration --repository-name app --image-scanning-configuration scanOnPush=true` |
| Lifecycle policy | `aws ecr put-lifecycle-policy --repository-name app --lifecycle-policy-text file://policy.json` |

## Ловушки

| ⚠️ | Суть |
| :--- | :--- |
| `:latest` в production | непредсказуемая версия; пинить тег и лучше digest |
| `ENV`/`ARG` с секретом | виден в `docker history` / `docker inspect`; использовать `RUN --mount=type=secret` |
| `.trivyignore` без комментария | через полгода никто не знает, почему CVE подавлен |
| 0 CVE у distroless | не значит «безопасно»: уязвимости в вашем коде сканер ОС не видит |
| БД Trivy в CI без кэша | каждая сборка качает БД; кэшировать каталог `TRIVY_CACHE_DIR` |

> Проверка: флаги `trivy` 0.66.0 (`image`/`sbom`/`clean`), `grype`
> v0.100.0, `syft` v1.33.0, `cosign` v2.6.1 (`sign`/`verify`/`tree`) —
> `--help` в Docker; не проверено: `crane`, `aws ecr` (только по
> документации), Kyverno-политика на живом кластере.
