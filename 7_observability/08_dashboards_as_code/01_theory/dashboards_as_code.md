# Dashboards as Code

## Проблема ручных дашбордов

- Создан вручную в UI → нет истории изменений
- Скопирован между Grafana инстансами → расхождения
- Удалён случайно → восстановить нельзя
- Разные окружения → разные дашборды (должны быть одинаковые)

**Решение:** хранить дашборды в git как JSON/Jsonnet, деплоить автоматически.

## Вариант 1 — Grafana Provisioning (простой)

```yaml
# grafana/provisioning/dashboards/dashboard.yaml
apiVersion: 1
providers:
  - name: default
    type: file
    updateIntervalSeconds: 30
    options:
      path: /etc/grafana/provisioning/dashboards
      foldersFromFilesStructure: true
```

```bash
# Экспортировать существующий дашборд как JSON
curl -s http://admin:admin@localhost:3000/api/dashboards/uid/my-dashboard-uid \
  | jq '.dashboard | del(.id, .uid)' > dashboard.json
# Сохранить в папку provisioning/dashboards/
# Grafana подхватит автоматически
```

```yaml
# В k8s: ConfigMap с дашбордом
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"   # grafana-sidecar подхватит автоматически
data:
  my-dashboard.json: |
    {
      "title": "My Dashboard",
      "panels": [...]
    }
```

## Вариант 2 — Grafonnet (Jsonnet)

Jsonnet — язык шаблонизации данных. Grafonnet — Jsonnet библиотека для Grafana.

```jsonnet
// dashboards/api-dashboard.jsonnet
local grafana = import 'grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local row = grafana.row;
local singlestat = grafana.singlestat;
local graphPanel = grafana.graphPanel;
local prometheus = grafana.prometheus;

dashboard.new(
  'API Dashboard',
  refresh='1m',
  time_from='now-1h',
  tags=['api', 'production'],
)
.addTemplate(
  grafana.template.datasource('datasource', 'prometheus', 'Prometheus', label='Datasource')
)
.addTemplate(
  grafana.template.new(
    'namespace',
    '$datasource',
    'label_values(kube_pod_info, namespace)',
    label='Namespace',
    refresh='load',
  )
)
.addPanel(
  graphPanel.new(
    'Request Rate',
    datasource='$datasource',
    legend_show=true,
  ).addTarget(
    prometheus.target(
      'sum by(service)(rate(http_requests_total{namespace="$namespace"}[5m]))',
      legendFormat='{{service}}'
    )
  ),
  gridPos={ h: 8, w: 12, x: 0, y: 0 }
)
```

```bash
# Генерировать JSON из Jsonnet
jsonnet -J grafonnet-lib dashboards/api-dashboard.jsonnet > api-dashboard.json

# В CI
for file in dashboards/*.jsonnet; do
  jsonnet -J grafonnet-lib "$file" > "generated/$(basename "$file" .jsonnet).json"
done
```

## Вариант 3 — grafana-operator (k8s-native)

```yaml
# GrafanaDashboard CRD
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: api-dashboard
  namespace: monitoring
spec:
  instanceSelector:
    matchLabels:
      dashboards: grafana
  json: |
    {
      "title": "API Dashboard",
      "panels": [
        {
          "type": "graph",
          "title": "Request Rate",
          "targets": [{
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "{{service}}"
          }]
        }
      ]
    }
```

## Вариант 4 — Grafana API в CI

```bash
# Деплоить дашборд через API в CI
deploy_dashboard() {
  local file=$1
  local uid=$(jq -r '.uid' "$file")
  
  curl -s -X POST http://admin:${GRAFANA_PASSWORD}@grafana:3000/api/dashboards/db \
    -H "Content-Type: application/json" \
    -d "{
      \"dashboard\": $(cat "$file"),
      \"overwrite\": true,
      \"folderId\": 0
    }"
}

for dashboard in dashboards/*.json; do
  deploy_dashboard "$dashboard"
done
```

## Рекомендуемый workflow

```
1. Дизайн дашборда вручную в Grafana (staging)
2. Экспортировать JSON через API
3. Очистить от ephemeral полей (id, version):
   jq 'del(.id, .version)' dashboard.json > dashboard-clean.json
4. Сохранить в git
5. CI деплоит в production Grafana через API или Provisioning
6. При изменении — через PR, review, merge, деплой
```

## Структура репозитория

```
monitoring/
├── dashboards/
│   ├── infrastructure/
│   │   ├── nodes.json
│   │   ├── kubernetes.json
│   │   └── network.json
│   ├── applications/
│   │   ├── api-service.json
│   │   └── payment-service.json
│   └── business/
│       ├── revenue.json
│       └── conversions.json
├── alerts/
│   ├── infrastructure.yaml
│   └── applications.yaml
└── datasources/
    └── prometheus.yaml
```
