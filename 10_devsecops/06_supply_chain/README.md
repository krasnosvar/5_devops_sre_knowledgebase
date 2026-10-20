# 06. Supply Chain Security

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — команды и шаблоны одним экраном.

## Зачем
Атаки через зависимости и сборочную инфраструктуру обходят все проверки
на стороне кластера: вредоносный код приходит уже внутри «доверенного»
артефакта. Тема: SBOM, подпись артефактов (Sigstore), уровни SLSA,
защита зависимостей.

## Пререквизиты
- [04_image_security](../04_image_security/) — Cosign и Kyverno
  verifyImages.
- [6_cicd](../../6_cicd/) — pipeline, в котором генерируются SBOM и
  provenance.

## Файлы
- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: SBOM, аттестации, SLSA.
- [01_theory/supply_chain_security.md](./01_theory/supply_chain_security.md)
  — SBOM (Syft/Grype), Cosign, Kyverno, SLSA Build track v1.0,
  Dependabot/Renovate, чеклист.
- Без примеров и упражнений: подпись keyless и provenance требуют
  OIDC от реального CI (GitHub Actions/GitLab).

## Как проходить
1. Прочитать теорию.
2. Локально: сгенерировать SBOM своего образа через Syft и прогнать его
   через Grype.

## Когда двигаться дальше
- Можете объяснить, что гарантирует SLSA Build L2 и чем от него
  отличается L3.
- Можете объяснить, как keyless-подпись связывает образ с workflow.

Далее: [07_sast_in_ci](../07_sast_in_ci/).
