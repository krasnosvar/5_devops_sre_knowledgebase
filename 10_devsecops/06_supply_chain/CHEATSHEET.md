# Supply Chain Security — шпаргалка

Подробности и объяснения — в
[01_theory/supply_chain_security.md](./01_theory/supply_chain_security.md).
⚠️ — опасная команда или частая ловушка.

## Что от чего защищает

| Угроза | Мера |
| :--- | :--- |
| Уязвимая/вредоносная зависимость | lock-файлы, пиннинг, Dependabot/Renovate, скан SBOM |
| Подмена образа в registry | подпись (Cosign) + проверка при деплое (Kyverno), immutable tags |
| Скомпрометированная сборка | provenance (SLSA), изолированные hosted-раннеры |
| «Что у нас внутри, если завтра новый Log4Shell?» | SBOM на каждый build + повторный скан |

## SBOM

| Задача | Команда |
| :--- | :--- |
| SBOM образа (SPDX / CycloneDX) | `syft registry/app:1.0 -o spdx-json > sbom.spdx.json`<br>`syft registry/app:1.0 -o cyclonedx-json > sbom.cdx.json` |
| SBOM каталога проекта | `syft dir:. -o cyclonedx-json > sbom.json` |
| Несколько форматов за раз | `syft app:1.0 -o spdx-json=sbom.spdx.json -o cyclonedx-json=sbom.cdx.json` |
| SBOM через Trivy | `trivy image --format cyclonedx -o sbom.cdx.json app:1.0` |
| CVE по SBOM | `grype sbom:./sbom.json` / `trivy sbom sbom.cdx.json` |

| Формат | Где встречается |
| :--- | :--- |
| SPDX | стандарт ISO, лицензии, комплаенс |
| CycloneDX | OWASP, безопасность, VEX, Dependency-Track |

## Cosign: подписи и аттестации

| Задача | Команда |
| :--- | :--- |
| Keyless-подпись в CI (OIDC) | `cosign sign --yes $IMAGE@$DIGEST` |
| Подпись ключом | `cosign sign --key cosign.key $IMAGE@$DIGEST` |
| Проверка keyless | `cosign verify $IMAGE --certificate-identity=<workflow-URL@ref> --certificate-oidc-issuer=https://token.actions.githubusercontent.com` |
| Прикрепить SBOM как аттестацию | `cosign attest --yes --type cyclonedx --predicate sbom.cdx.json $IMAGE@$DIGEST` |
| Проверить аттестацию | `cosign verify-attestation --type cyclonedx --certificate-identity=... --certificate-oidc-issuer=... $IMAGE` |
| Подписать файл (blob) | `cosign sign-blob --yes --bundle app.bundle app.tar.gz` |
| Проверить blob | `cosign verify-blob --bundle app.bundle --certificate-identity=... --certificate-oidc-issuer=... app.tar.gz` |
| Что привязано к образу | `cosign tree $IMAGE` |

| CI | Что нужно для keyless |
| :--- | :--- |
| GitHub Actions | `permissions: id-token: write`; issuer `https://token.actions.githubusercontent.com` |
| GitLab CI | `id_tokens: SIGSTORE_ID_TOKEN: {aud: sigstore}`; issuer — URL инстанса GitLab |

## SLSA v1.0 (Build track)

| Уровень | Требование |
| :--- | :--- |
| Build L0 | ничего |
| Build L1 | provenance существует |
| Build L2 | hosted build-платформа, provenance подписан платформой |
| Build L3 | hardened платформа: изоляция сборок, ключи недоступны шагам |

```yaml
# GitHub Actions: provenance — reusable workflow, уровень job, не step
provenance:
  needs: build
  permissions: {actions: read, id-token: write, packages: write}
  uses: slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@v2.0.0
  with:
    image: ${{ needs.build.outputs.image }}
    digest: ${{ needs.build.outputs.digest }}
```

| Задача | Команда |
| :--- | :--- |
| Проверить provenance | `slsa-verifier verify-image $IMAGE@$DIGEST --source-uri github.com/org/app` |
| GitHub artifact attestations | `gh attestation verify oci://$IMAGE --owner org` |

## Зависимости

| Экосистема | Строгая установка по lock-файлу |
| :--- | :--- |
| npm | `npm ci` (не `npm install`) |
| pip | `pip install --require-hashes -r requirements.txt` |
| Go | `go mod verify` (сверка с `go.sum`) |
| Poetry / uv | `poetry sync` (Poetry 2.x) / `uv sync --locked` |

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: npm
    directory: "/"
    schedule: {interval: weekly}
    groups:
      production-deps: {patterns: ["*"]}
```

## Ловушки

| ⚠️ | Суть |
| :--- | :--- |
| Подпись по тегу | тег перезаписывается — подписывать `@sha256:...` |
| `COSIGN_EXPERIMENTAL=1` | не нужен с cosign 2.x: keyless по умолчанию |
| SLSA 1–4 (v0.1) | устаревшая шкала; в v1.0 — Build L0–L3 |
| `uses:` генератора SLSA в `steps` | это reusable workflow — только на уровне job |
| Range-версии (`^4.18.0`) без lock-файла | может приехать скомпрометированный релиз |
| Сторонние Actions по тегу | пиннить по полному SHA коммита |

> Проверка: `cosign` v2.6.1 (`attest`, `verify-attestation`,
> `sign-blob`, `tree`), `syft` v1.33.0, `trivy` 0.66.0 — `--help` в
> Docker; не проверено: `slsa-verifier`, `gh attestation`, реальная
> keyless-подпись (нужен OIDC в CI).
