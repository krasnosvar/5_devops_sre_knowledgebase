# Grafana — шпаргалка

Подробности и объяснения — в [grafana.md](./01_theory/grafana.md).
⚠️ — опасная команда или частая ловушка.

## Переменные и макросы

| Задача | Что писать |
| :--- | :--- |
| Список значений метки (Prometheus) | `label_values(up, cluster)` |
| Связанная переменная (chaining) | `label_values(kube_pod_info{cluster="$cluster"}, namespace)` |
| Значения из результата запроса + regex | `query_result(topk(5, sum by (pod) (rate(x[5m]))))`, Regex: `/pod="([^"]+)"/` |
| Multi-value / All в PromQL | `{namespace=~"$namespace"}` ⚠️ не `=` |
| Окно для `rate()` в панели | `rate(x[$__rate_interval])` (≥ 4× scrape interval) |
| Шаг под ширину графика | `$__interval` (для `*_over_time`, не для `rate`) |
| Весь выбранный диапазон | `increase(x[$__range])` |
| Формат значения переменной | `${var:pipe}`, `${var:csv}`, `${var:regex}`, `${var:json}` |
| Короткая легенда | Legend: `{{pod}}` или `{{namespace}}/{{pod}}` |
| Переносимый datasource | переменная типа Data source `${DS_PROMETHEUS}` |

## Provisioning

Каталоги: `/etc/grafana/provisioning/{datasources,dashboards,alerting,plugins}/`.

```yaml
# datasources/ds.yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    uid: prometheus          # фиксированный uid — дашборды ссылаются на него
    url: http://prometheus:9090
    isDefault: true
  - name: Loki
    type: loki
    uid: loki
    url: http://loki:3100
```

```yaml
# dashboards/provider.yaml
apiVersion: 1
providers:
  - name: default
    type: file
    folder: Infra
    allowUiUpdates: false     # true — можно сохранять из UI (дрейф от Git)
    updateIntervalSeconds: 30
    options:
      path: /var/lib/grafana/dashboards
      foldersFromFilesStructure: false
```

⚠️ `folder` и `foldersFromFilesStructure: true` вместе не задают.

## Конфигурация через env

| Задача | Переменная |
| :--- | :--- |
| Пароль admin | `GF_SECURITY_ADMIN_PASSWORD=...` |
| Любой ключ `grafana.ini` | `GF_<SECTION>_<KEY>`, напр. `GF_AUTH_ANONYMOUS_ENABLED=true` |
| Плагины при старте | `GF_PLUGINS_PREINSTALL=grafana-clock-panel` |
| Root URL за прокси | `GF_SERVER_ROOT_URL=https://grafana.example.com/` |
| Маппинг ролей из OIDC | `GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH="contains(groups[*], 'sre') && 'Admin' \|\| 'Viewer'"` |

## HTTP API

| Задача | Команда |
| :--- | :--- |
| Здоровье | `curl -s localhost:3000/api/health` |
| Список дашбордов | `curl -s -u admin:admin 'localhost:3000/api/search?type=dash-db'` |
| Выгрузить дашборд | `curl -s -H "Authorization: Bearer $TOKEN" localhost:3000/api/dashboards/uid/<uid> \| jq .dashboard` |
| Загрузить / перезаписать | `curl -s -X POST -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"dashboard": {...}, "overwrite": true}' localhost:3000/api/dashboards/db` |
| Аннотация деплоя | `curl -s -X POST ... -d '{"text":"Deploy v1.5","tags":["deploy"]}' localhost:3000/api/annotations` |
| Перечитать provisioning дашбордов | `curl -s -X POST -u admin:admin localhost:3000/api/admin/provisioning/dashboards/reload` |
| Service account + токен | `POST /api/serviceaccounts` `{"name":"ci","role":"Editor"}` → `POST /api/serviceaccounts/<id>/tokens` `{"name":"ci"}` |
| Список datasources | `curl -s -u admin:admin localhost:3000/api/datasources \| jq '.[].name'` |

⚠️ При POST дашборда убирать `id` (`jq 'del(.id)'`), иначе конфликт
между инстансами; идентификатор переносимости — `uid`.

## Когда что использовать

| Задача | Выбор |
| :--- | :--- |
| Инфраструктурные алерты (нода, диск, SLO) | Prometheus rules + Alertmanager (`PrometheusRule` в Git) |
| Алерт на SQL/бизнес-метрику | Grafana Alerting |
| Ad-hoc расследование метрик/логов/трейсов | Explore |
| Склеить данные из двух источников | Transformations (`Join by field`, `Merge`) |
| Связь деплоя с графиком | Annotations через API из CI |
| Графики в Slack-уведомлениях | Image Renderer отдельным подом |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| `Data source not found` после импорта | uid datasource в JSON; использовать `${DS_PROMETHEUS}` |
| Multi-value ломает запрос | `=~` вместо `=` |
| График «пилой» / пустой при zoom-out | `$__rate_interval` вместо фиксированного `[1m]` |
| Кнопка Save недоступна | дашборд из provisioning, `allowUiUpdates: false` |
| Панель грузится долго | тяжёлый PromQL → recording rule; Query inspector |
| SSO-пользователь всегда Viewer | `role_attribute_path` / role sync групп IdP |

> Проверка: provisioning-файлы и API-вызовы прогнаны на
> grafana/grafana:12.1.0 в Docker (health, search, dashboards/db,
> annotations, provisioning reload, serviceaccounts); не проверено:
> OIDC-маппинг ролей, `GF_PLUGINS_PREINSTALL` (нужна сеть к каталогу).
