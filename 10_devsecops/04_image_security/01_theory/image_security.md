# Container Image Security

## Слои атаки на образы

```
1. Base image → CVE в OS пакетах (старый Ubuntu, уязвимый openssl)
2. Application deps → CVE в npm/pip/maven зависимостях (Log4Shell)
3. Dockerfile → неправильная конфигурация (root, secrets в ENV, latest tag)
4. Registry → отравление образа, подмена тега
5. Runtime → escape из контейнера через уязвимость ядра
```

## Минимизация attack surface

```dockerfile
# Плохо: большой образ = большая поверхность атаки
FROM ubuntu:latest
RUN apt install python3 curl wget git build-essential ...
COPY . .
RUN pip install -r requirements.txt
CMD python app.py

# Хорошо: минимальный образ
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM gcr.io/distroless/python3-debian12    # Google Distroless
# Нет shell, нет package manager, нет /tmp, нет лишних утилит
WORKDIR /app
COPY --from=builder /usr/local/lib/python3.12 /usr/local/lib/python3.12
COPY --from=builder /usr/local/bin/python3 /usr/local/bin/python3
COPY . .
ENTRYPOINT ["python3", "app.py"]
```

**Базовые образы по безопасности (от меньшего к большему):**
1. `scratch` — пустой, только ваш бинарник (только статически слинкованные бинарники)
2. `gcr.io/distroless/static` — минимальный Linux без shell и package manager
3. `gcr.io/distroless/python3` / `nodejs` — дистроless с рантаймом
4. `alpine:3.x` — 5 MB, минимальный musl libc, busybox
5. `debian:slim` / `python:3.x-slim` — популярный компромисс

## Trivy — сканирование CVE

```bash
# Установка
brew install aquasecurity/trivy/trivy   # macOS
dnf install trivy                       # Fedora

# Сканировать образ
trivy image nginx:latest
trivy image --severity HIGH,CRITICAL nginx:latest
trivy image --exit-code 1 --severity CRITICAL nginx:latest  # fail if critical

# Сканировать filesystem (зависимости в директории)
trivy fs .
trivy fs --scanners vuln,secret .

# Отчёт в разных форматах
trivy image --format json nginx:latest | jq '.Results[].Vulnerabilities[] | select(.Severity=="CRITICAL")'
trivy image --format table nginx:latest
trivy image --format sarif --output results.sarif nginx:latest   # для GitHub

# Игнорировать конкретные CVE (с обоснованием)
# .trivyignore
CVE-2023-1234  # not exploitable in our config
CVE-2023-5678  # fixed in next sprint, tracked in JIRA-1234
```

## Grype — альтернатива Trivy

```bash
# Установка
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh

# Сканировать
grype nginx:latest
grype dir:.                      # директория
grype sbom:app-sbom.json         # из SBOM файла

# Только критические
grype nginx:latest --fail-on critical

# Генерировать SBOM и сканировать
syft nginx:latest -o cyclonedx-json > sbom.json
grype sbom:sbom.json
```

## Подписание образов (Cosign)

```bash
# Установка
brew install sigstore/tap/cosign

# Keyless подписание (через OIDC — GitHub Actions / GitLab)
# В GitHub Actions:
# - name: Sign image
#   run: cosign sign --yes $IMAGE:$SHA
#   env:
#     COSIGN_EXPERIMENTAL: "1"

# Подписать с ключом
cosign generate-key-pair
cosign sign --key cosign.key my-registry/myapp:v1.0

# Верифицировать
cosign verify my-registry/myapp:v1.0 \
  --certificate-identity=ci@example.com \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com

# Верифицировать с ключом
cosign verify --key cosign.pub my-registry/myapp:v1.0
```

## Проверка подписи при деплое (Kyverno)

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-signed-images
spec:
  validationFailureAction: enforce
  rules:
    - name: verify-signature
      match:
        any:
          - resources:
              kinds: [Pod]
              namespaces: [production, staging]
      verifyImages:
        - imageReferences:
            - "ghcr.io/org/*"
          attestors:
            - entries:
                - keyless:
                    subject: "https://github.com/org/app/.github/workflows/ci.yaml@refs/heads/main"
                    issuer: "https://token.actions.githubusercontent.com"
```

## Immutable tags в Registry

```bash
# ECR — включить tag immutability (нельзя перезаписать тег)
aws ecr put-image-tag-mutability \
  --repository-name myapp \
  --image-tag-mutability IMMUTABLE

# Harbor — immutable tags через retention policy
# GHCR — immutable по умолчанию для SHA-теги

# Никогда не использовать :latest в production
# Всегда: :sha256-abc123def или :v1.2.3
```

## Lifecycle policy — убирать старые образы

```bash
# ECR lifecycle
aws ecr put-lifecycle-policy \
  --repository-name myapp \
  --lifecycle-policy-text '{
    "rules": [{
      "rulePriority": 1,
      "description": "Keep last 30 images",
      "selection": {
        "tagStatus": "tagged",
        "countType": "imageCountMoreThan",
        "countNumber": 30
      },
      "action": {"type": "expire"}
    }]
  }'

# Harbor: Schedule → настроить garbage collection
# Удалять образы старше 90 дней и не tagged как :latest или :v*
```

## Чеклист безопасности образов

```
□ Base image: slim/distroless/alpine (не full ubuntu/centos)
□ Multi-stage build: dev deps не попадают в prod образ
□ Не запускать как root (USER appuser)
□ Не хранить секреты в ENV или ARG (видны в docker inspect)
□ Пинировать версии базового образа (не :latest)
□ Trivy/Grype в CI: fail при CRITICAL CVE
□ SBOM генерируется при каждом build
□ Образ подписан (Cosign)
□ Kyverno проверяет подпись при деплое
□ Lifecycle policy: удалять старые образы
□ Immutable tags в registry
```
