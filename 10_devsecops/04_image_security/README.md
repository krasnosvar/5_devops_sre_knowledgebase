# 04. Безопасность образов

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — команды и шаблоны одним экраном.

## Зачем
Каждый образ тянет сотни пакетов с известными CVE, а без подписи нельзя
доказать, что в кластер попал именно тот образ, который собрал CI. Тема:
сканирование (Trivy, Grype), минимальные образы, подпись Cosign и
проверка подписи при деплое.

## Пререквизиты
- [3_containers/02_image_layers](../../3_containers/02_image_layers/) и
  [07_dockerfile_best_practices](../../3_containers/07_dockerfile_best_practices/).
- Kyverno: подробно в
  [4_kubernetes/06_security/02_policy_engines](../../4_kubernetes/06_security/02_policy_engines/);
  здесь достаточно понимать, что это admission controller с политиками в
  YAML.

## Файлы
- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: Trivy, Grype, Cosign.
- [01_theory/image_security.md](./01_theory/image_security.md) —
  attack surface, Trivy, Grype, Cosign, Kyverno verifyImages, immutable
  tags, lifecycle policy.
- [02_examples/scan-images.sh](./02_examples/scan-images.sh) — сравнение
  базовых образов по числу CVE через Trivy.
- Упражнений нет: достаточно примера и сканирования собственных образов.

## Как проходить
1. Прочитать теорию.
2. Установить Trivy и запустить `scan-images.sh`.
3. Просканировать образ своего приложения и разобрать HIGH/CRITICAL.

## Когда двигаться дальше
- Можете объяснить, почему distroless уменьшает число CVE и что теряется.
- Можете подписать образ Cosign и проверить подпись.

Далее: [05_pod_security](../05_pod_security/).
