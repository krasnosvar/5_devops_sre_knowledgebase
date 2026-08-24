# Helm — пакетный менеджер Kubernetes

## Концепции

**Chart** — пакет шаблонов k8s манифестов + values.
**Release** — задеплоенный экземпляр chart с конкретными values.
**Repository** — хранилище chart'ов (Artifact Hub, Harbor, OCI registry).

## Структура chart'а

```
mychart/
├── Chart.yaml          # метаданные (name, version, appVersion)
├── values.yaml         # значения по умолчанию
├── values-prod.yaml    # overrides для prod (не входит в chart)
├── templates/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── configmap.yaml
│   ├── _helpers.tpl    # переиспользуемые шаблоны (именованные template)
│   └── NOTES.txt       # выводится после helm install
├── charts/             # зависимости (subcharts)
└── .helmignore
```

## Шаблонизация — основные конструкции

```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "mychart.fullname" . }}   # именованный шаблон из _helpers.tpl
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  {{- if .Values.autoscaling.enabled }}
  # не рендерить если autoscaling включён
  {{- end }}
  template:
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          ports:
            - containerPort: {{ .Values.service.port }}
          {{- with .Values.resources }}
          resources:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- if .Values.env }}
          env:
            {{- range $key, $value := .Values.env }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
          {{- end }}
```

```yaml
# values.yaml
replicaCount: 1

image:
  repository: nginx
  tag: ""              # если пусто — используется Chart.AppVersion

service:
  type: ClusterIP
  port: 80

resources:
  limits:
    cpu: 200m
    memory: 128Mi
  requests:
    cpu: 100m
    memory: 64Mi

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80

env: {}
  # LOG_LEVEL: info
  # ENV: production
```

## Команды

```bash
# поиск chart'ов
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo bitnami/postgresql
helm show values bitnami/postgresql | less

# установка
helm install my-postgres bitnami/postgresql \
  --namespace db \
  --create-namespace \
  --values custom-values.yaml \
  --set auth.postgresPassword=secret \
  --wait \
  --timeout 5m

# обновление (идемпотентно: install если нет, upgrade если есть)
helm upgrade --install my-postgres bitnami/postgresql \
  --namespace db \
  -f custom-values.yaml \
  --set image.tag=16.2.0

# список релизов
helm list -A             # все namespace
helm list -n db

# история и rollback
helm history my-postgres -n db
helm rollback my-postgres 2 -n db   # откатить к ревизии 2

# рендер без деплоя (для отладки)
helm template my-postgres bitnami/postgresql \
  -f custom-values.yaml \
  --set auth.postgresPassword=secret | kubectl apply --dry-run=client -f -

# diff (плагин helm-diff)
helm diff upgrade my-postgres bitnami/postgresql -f custom-values.yaml

# удалить
helm uninstall my-postgres -n db
```

## _helpers.tpl — переиспользуемые блоки

```
{{/*  _helpers.tpl  */}}

{{- define "mychart.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "mychart.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
```

## Helmfile — декларативное управление множеством релизов

```yaml
# helmfile.yaml
repositories:
  - name: bitnami
    url: https://charts.bitnami.com/bitnami

environments:
  staging:
    values:
      - envs/staging.yaml
  production:
    values:
      - envs/production.yaml

releases:
  - name: postgres
    namespace: db
    chart: bitnami/postgresql
    version: "14.3.3"
    values:
      - values/postgres.yaml.gotmpl

  - name: myapp
    namespace: production
    chart: ./charts/myapp
    values:
      - values/myapp.yaml.gotmpl
    needs:
      - db/postgres          # деплоить после postgres
```

```bash
helmfile sync             # применить всё
helmfile diff             # показать изменения
helmfile apply            # diff + sync
helmfile --environment production sync
```
