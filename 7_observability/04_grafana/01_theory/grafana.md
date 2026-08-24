# Grafana

## Концепции

**Datasource** — источник данных: Prometheus, Loki, Tempo, InfluxDB, PostgreSQL, etc.
**Dashboard** — набор панелей (panels) для визуализации.
**Panel** — отдельный график/таблица/gauge на дашборде.
**Alert** — правило оповещения на основе данных из datasource.

## Datasources

```bash
# Grafana API — добавить datasource программно
curl -X POST http://admin:admin@localhost:3000/api/datasources \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Prometheus",
    "type": "prometheus",
    "url": "http://prometheus:9090",
    "access": "proxy",
    "isDefault": true
  }'

# Provisioning через файл (лучший способ — GitOps)
# grafana/provisioning/datasources/prometheus.yaml
```

```yaml
# grafana/provisioning/datasources/datasources.yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    url: http://prometheus:9090
    isDefault: true
    jsonData:
      timeInterval: 15s

  - name: Loki
    type: loki
    url: http://loki:3100
    jsonData:
      derivedFields:
        - name: TraceID
          matcherRegex: '"trace_id":"(\w+)"'
          url: '$${__value.raw}'
          datasourceUid: tempo   # кликабельная ссылка в логах → trace

  - name: Tempo
    uid: tempo
    type: tempo
    url: http://tempo:3200
```

## Dashboard Provisioning — дашборды как код

```yaml
# grafana/provisioning/dashboards/dashboards.yaml
apiVersion: 1
providers:
  - name: default
    type: file
    updateIntervalSeconds: 30
    options:
      path: /etc/grafana/provisioning/dashboards
      foldersFromFilesStructure: true
# помещаем JSON дашбордов рядом с этим файлом
```

```bash
# экспортировать дашборд как JSON
curl -s http://admin:admin@localhost:3000/api/dashboards/uid/my-dashboard \
  | jq '.dashboard' > my-dashboard.json

# импортировать
curl -X POST http://admin:admin@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d "{\"dashboard\": $(cat my-dashboard.json), \"overwrite\": true}"
```

## Alerting в Grafana

```yaml
# grafana/provisioning/alerting/rules.yaml — Unified Alerting (Grafana 9+)
apiVersion: 1
groups:
  - orgId: 1
    name: SLO Alerts
    folder: Production
    interval: 1m
    rules:
      - uid: high-error-rate
        title: High Error Rate
        condition: C
        data:
          - refId: A
            queryType: ''
            relativeTimeRange:
              from: 300
              to: 0
            datasourceUid: prometheus
            model:
              expr: |
                rate(http_requests_total{status=~"5.."}[5m])
                / rate(http_requests_total[5m]) > 0.01
              intervalMs: 1000
              maxDataPoints: 43200

        noDataState: NoData
        execErrState: Error
        for: 5m
        labels:
          severity: warning
          team: backend
        annotations:
          summary: "Error rate high on {{ $labels.service }}"
          runbook_url: "https://wiki/runbooks/high-error-rate"
```

```yaml
# Contact Points — куда слать алерты
apiVersion: 1
contactPoints:
  - orgId: 1
    name: slack-alerts
    receivers:
      - uid: slack-1
        type: slack
        settings:
          url: "https://hooks.slack.com/services/YOUR/WEBHOOK"
          channel: "#alerts"
          title: "{{ .CommonLabels.alertname }}"
          text: "{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}"
```

## Переменные и шаблонизация дашбордов

```
В UI: Dashboard Settings → Variables → Add Variable

Type: Query
Name: namespace
Datasource: Prometheus
Query: label_values(kube_pod_info, namespace)
Refresh: On Dashboard Load

Использование в панели:
  kube_pod_status_phase{namespace="$namespace"}
  rate(http_requests_total{namespace="$namespace"}[5m])
```

## Полезные API

```bash
BASE="http://admin:admin@localhost:3000"

# список дашбордов
curl -s "$BASE/api/search?type=dash-db" | jq '.[].title'

# список datasources
curl -s "$BASE/api/datasources" | jq '.[].name'

# health check
curl -s "$BASE/api/health"

# метрики самой Grafana (для мониторинга Grafana)
curl -s "$BASE/metrics" | grep grafana_

# annotations — отметить деплой на графике
curl -X POST "$BASE/api/annotations" \
  -H "Content-Type: application/json" \
  -d "{
    \"text\": \"Deployed myapp v$VERSION\",
    \"tags\": [\"deployment\", \"myapp\"],
    \"time\": $(date +%s)000
  }"
```

## Grafana в k8s через Helm

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm upgrade --install grafana grafana/grafana \
  --namespace monitoring \
  --set adminPassword=secret \
  --set persistence.enabled=true \
  --set persistence.size=5Gi \
  --values grafana-values.yaml
```

```yaml
# grafana-values.yaml
grafana.ini:
  server:
    root_url: https://grafana.example.com
  auth.generic_oauth:
    enabled: true
    client_id: grafana
    client_secret: secret
    scopes: openid email profile
    auth_url: https://keycloak.example.com/realms/main/protocol/openid-connect/auth
    token_url: https://keycloak.example.com/realms/main/protocol/openid-connect/token

sidecar:
  dashboards:
    enabled: true   # автоматически подхватывать ConfigMap с label grafana_dashboard=1
  datasources:
    enabled: true   # автоматически подхватывать ConfigMap с label grafana_datasource=1
```
