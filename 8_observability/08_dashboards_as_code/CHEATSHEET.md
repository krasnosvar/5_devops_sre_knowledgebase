# Dashboards as Code — шпаргалка

Подробности и объяснения — в
[dashboards_as_code.md](./01_theory/dashboards_as_code.md). ⚠️ — опасная
команда или частая ловушка.

## Когда что использовать

| Подход | Когда | Минус |
| :--- | :--- | :--- |
| Provisioning: JSON-файлы + YAML-провайдер | одна Grafana, Docker Compose, VM | большой JSON плохо ревьюить |
| ConfigMap + sidecar (kube-prometheus-stack) | Grafana из Helm-чарта, дашборд рядом с приложением | тот же JSON внутри ConfigMap |
| `GrafanaDashboard` CRD (Grafana Operator) | GitOps, много команд и инстансов Grafana | ещё один оператор |
| Jsonnet / Grafonnet, mixins | десятки похожих дашбордов, переиспользование | язык и сборка в CI |
| Terraform provider | Grafana — часть IaC (папки, права, datasources) | Terraform не проверяет PromQL |
| HTTP API + `curl` из CI | разовый экспорт/импорт, аннотации | императивно: дрейф не исправляется |

## Provisioning из файлов

```yaml
# /etc/grafana/provisioning/dashboards/teams.yaml
apiVersion: 1
providers:
  - name: team-a
    folder: Team A
    type: file
    allowUiUpdates: false    # Save в UI заблокирован — источник истины Git
    options:
      path: /var/lib/grafana/dashboards/team-a
  - name: team-b
    folder: Team B
    type: file
    options:
      path: /var/lib/grafana/dashboards/team-b
```

## Kubernetes: sidecar и оператор

| Задача | Как |
| :--- | :--- |
| Дашборд для sidecar kube-prometheus-stack | ConfigMap с лейблом `grafana_dashboard: "1"` и JSON в `data` |
| Создать такой ConfigMap | `kubectl create configmap app-dash --from-file=app.json -n monitoring --dry-run=client -o yaml` + лейбл |
| Папка для sidecar | аннотация `grafana_folder: "Team A"` (`sidecar.dashboards.folderAnnotation` в values) |
| Dashboard через Grafana Operator | CRD `GrafanaDashboard` (ниже) |

```yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: my-app
  namespace: team-a
spec:
  instanceSelector:            # в какую Grafana (CR Grafana) загрузить
    matchLabels:
      dashboards: grafana
  folder: Team A
  json: |
    {"title": "My App", "uid": "my-app", "panels": []}
```

⚠️ `GrafanaDashboard` — CRD Grafana Operator, а не Prometheus Operator;
старый `integreatly.org/v1alpha1` не поддерживается.

## Jsonnet / Grafonnet / mixins

| Задача | Команда |
| :--- | :--- |
| Поставить Grafonnet | `jb init && jb install github.com/grafana/grafonnet/gen/grafonnet-latest@main` |
| Собрать JSON | `jsonnet -J vendor dashboard.jsonnet > dashboard.json` |
| Много файлов из одного источника | `jsonnet -J vendor -m out/ dashboards.jsonnet` |
| Форматирование / линт | `jsonnetfmt -i *.jsonnet`, `jsonnet-lint` |
| Mixin (дашборды + alerts + recording rules) | `jb install github.com/kubernetes-monitoring/kubernetes-mixin@master` |
| Проверить правила из mixin | `promtool check rules prometheus_rules.yaml` |

```jsonnet
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
g.dashboard.new('My App')
+ g.dashboard.withUid('my-app')
+ g.dashboard.withPanels([
  g.panel.timeSeries.new('RPS')
  + g.panel.timeSeries.queryOptions.withTargets([
    g.query.prometheus.new('${DS_PROMETHEUS}', 'sum(rate(http_requests_total[$__rate_interval]))'),
  ]),
])
```

## Terraform provider

```hcl
terraform {
  required_providers {
    grafana = { source = "grafana/grafana", version = "~> 4.0" }
  }
}

provider "grafana" {
  url  = "http://localhost:3000"
  auth = var.grafana_token # service account token
}

resource "grafana_folder" "prod" {
  title = "Prod"
}

resource "grafana_dashboard" "app" {
  folder      = grafana_folder.prod.uid
  config_json = file("${path.module}/dashboards/app.json")
}
```

## Экспорт / импорт через API

| Задача | Команда |
| :--- | :--- |
| Все дашборды → файлы | `./export-import.sh export ./dashboards` ([скрипт](./02_examples/export-import.sh)) |
| Файлы → Grafana | `./export-import.sh import ./dashboards` |
| Аннотация деплоя из CI | `./export-import.sh annotate api v1.5.0` |
| Убрать служебные поля перед коммитом | `jq '.dashboard \| del(.id, .version)'` |
| Валидность JSON в CI | `jq empty dashboards/*.json` |

## Ловушки

| ⚠️ Ловушка | Правильно |
| :--- | :--- |
| Хардкод `"datasource": "prometheus-prod"` | переменная `${DS_PROMETHEUS}` или фиксированный `uid` datasource |
| Импорт с чужим `id` | удалять `id`, ключ — `uid` |
| Правки из UI в provisioned дашборде | `allowUiUpdates: false`, менять только в Git |
| `curl` из CI как «GitOps» | дрейф не исправится; нужен reconcile (оператор / Argo CD) |

> Проверка: provisioning-провайдер — на grafana/grafana:12.1.0,
> HCL — `terraform validate` и `fmt -check` (provider grafana v4.50.0); не проверено: Jsonnet/Grafonnet
> и `jb` (нет `jsonnet`/`jb`), CRD Grafana Operator (нет кластера с
> оператором) — по документации проектов.
