# Supply Chain Security

## Что такое supply chain атака

Атака на цепочку поставок — компрометация через зависимости, а не напрямую.

**Известные примеры:**
- SolarWinds (2020) — malware внедрён в обновление ПО. 18k организаций пострадало.
- Log4Shell (2021) — уязвимость в популярной Java библиотеке.
- XZ Utils (2024) — бэкдор внедрён через длительный social engineering в open-source.
- Codecov (2021) — bash скрипт в CI скомпрометирован, украдены secrets.

## SBOM — Software Bill of Materials

SBOM = список всех компонентов и зависимостей вашего ПО.
Как «состав продукта» на упаковке еды.

```bash
# Syft — генерировать SBOM из образа
syft nginx:latest -o spdx-json > nginx-sbom.json
syft nginx:latest -o cyclonedx-json > nginx-sbom-cdx.json

# из директории проекта
syft dir:. -o spdx-json > app-sbom.json

# проверить на CVE используя SBOM
grype sbom:./app-sbom.json

# в CI: генерировать SBOM при каждом build
syft $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA -o spdx-json > sbom.json
# прикрепить как артефакт и отправить в registry
```

## Sigstore — подписание артефактов

### Cosign — подпись образов

```bash
# установка
brew install cosign   # macOS
go install github.com/sigstore/cosign/v2/cmd/cosign@latest

# подписать образ (keyless через OIDC — лучший способ)
# работает автоматически в GitHub Actions / GitLab CI с OIDC
cosign sign $IMAGE

# подписать с ключом
cosign generate-key-pair    # создаёт cosign.key и cosign.pub
cosign sign --key cosign.key $IMAGE

# проверить подпись
cosign verify $IMAGE --certificate-identity=ci@example.com \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com

# проверить подпись с ключом
cosign verify --key cosign.pub $IMAGE
```

```yaml
# GitHub Actions — автоматическое подписание
- name: Sign container image
  uses: sigstore/cosign-installer@v3
  
- name: Sign the published Docker image
  # keyless — режим по умолчанию в cosign 2.x, флаг COSIGN_EXPERIMENTAL
  # больше не нужен; job должен иметь `permissions: id-token: write`.
  # Подписывать лучше по digest, а не по тегу (тег можно перезаписать);
  # digest — из шага docker/build-push-action с id: build
  run: |
    cosign sign --yes ${{ env.IMAGE }}@${{ steps.build.outputs.digest }}
```

### Kyverno — проверять подпись при деплое в k8s

```yaml
# Политика: разрешать только подписанные образы
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-signed-images
spec:
  rules:
    - name: check-image-signature
      match:
        any:
          - resources:
              kinds: [Pod]
              namespaces: [production]
      verifyImages:
        - imageReferences: ["ghcr.io/org/*"]
          failureAction: Enforce   # Kyverno 1.13+ (было validationFailureAction)
          attestors:
            - entries:
                - keyless:
                    subject: "https://github.com/org/repo/.github/workflows/build.yaml@refs/heads/main"
                    issuer: "https://token.actions.githubusercontent.com"
```

## SLSA Framework — уровни безопасности

SLSA (Supply chain Levels for Software Artifacts) — фреймворк для
повышения доверия к артефактам. В актуальной спецификации v1.0 уровни
описаны в **Build track** (требования к сборке и provenance):

| Уровень | Требования |
|---------|-----------|
| Build L0 | Никаких гарантий (нет SLSA) |
| Build L1 | Provenance существует: видно, как и из чего собран артефакт |
| Build L2 | Сборка на hosted build-платформе, provenance подписан платформой |
| Build L3 | Hardened build-платформа: сборки изолированы друг от друга, ключи подписи недоступны шагам сборки |

Старая версия v0.1 описывала уровни SLSA 1–4 (с hermetic/reproducible
builds и two-party review на уровне 4) — эта шкала устарела и часто
встречается в старых статьях. Требования к исходникам (review кода) в
v1.0 в Build track не входят и развиваются отдельно.

```bash
# GitHub Actions — генерировать SLSA provenance автоматически
- uses: slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@v2.0.0
  with:
    image: ${{ env.IMAGE }}
    digest: ${{ steps.build.outputs.digest }}
```

## Защита зависимостей

```bash
# Pining точных версий (не ranges!)
# package.json — плохо
"dependencies": {
  "express": "^4.18.0"   # range → может подтянуть компрометированную версию
}

# package.json — хорошо
"dependencies": {
  "express": "4.18.2"    # exact version
}

# Использовать lock файлы (package-lock.json, Pipfile.lock, go.sum)
# И проверять их в CI

# Dependabot / Renovate — автоматические PR при обновлении зависимостей
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: npm
    directory: "/"
    schedule:
      interval: weekly
    groups:
      production-deps:
        patterns: ["*"]
```

## Минимальный чеклист

```
□ SBOM генерируется при каждом build
□ Образы подписываются в CI (Cosign)
□ Kyverno/OPA проверяет подпись при деплое
□ Зависимости пинированы + lock файлы в git
□ Dependabot/Renovate настроен для автообновления
□ Trivy сканирует зависимости в CI
□ Registry с immutable tags (нельзя перезаписать :latest)
□ Ротация signing ключей раз в год
```
