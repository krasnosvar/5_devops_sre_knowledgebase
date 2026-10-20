# Алертинг и Alertmanager — шпаргалка

Подробности и объяснения — в [alerting.md](./01_theory/alerting.md).
⚠️ — опасная команда или частая ловушка.

## Путь алерта

| Этап | Где | Что решается |
| :--- | :--- | :--- |
| Inactive → Pending → Firing | Prometheus / vmalert | `expr` истинно дольше `for:` |
| Дедупликация | Alertmanager | одинаковые лейблы от HA-пары Prometheus = один алерт |
| Маршрутизация | `route` / `routes` | первый совпавший маршрут (если не `continue: true`) |
| Группировка | `group_by` | один «конверт» на группу |
| Подавление | `inhibit_rules`, silences | глушить следствия и плановые работы |
| Уведомление | `receivers` | Slack, PagerDuty, email, webhook |

## Тайминги

| Параметр | Смысл | Дефолт | Типично |
| :--- | :--- | :--- | :--- |
| `group_wait` | ждать перед первым уведомлением группы | 30s | 30s (critical — 0s–10s) |
| `group_interval` | как часто досылать изменения группы | 5m | 5m |
| `repeat_interval` | напоминание, пока алерт Firing | 4h | 3h–12h |
| `resolve_timeout` | считать resolved, если алерт перестал приходить (без EndsAt) | 5m | 5m |
| `for:` в правиле | сколько держаться до Firing | 0 | 2m–15m |

⚠️ Новый алерт в уже отправленной группе придёт не раньше `group_interval`
после предыдущего уведомления.

## Конфиг: маршруты и подавление

```yaml
route:
  receiver: slack-default
  group_by: ['alertname', 'cluster', 'namespace']   # ⚠️ не '...' (все лейблы)
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 3h
  routes:
    - matchers: ['alertname="Watchdog"']
      receiver: "null"
    - matchers: ['severity="critical"']
      receiver: pagerduty
    - matchers: ['team=~"db|dba"', 'env="production"']
      receiver: slack-db
      continue: true                                 # искать дальше
    - matchers: ['severity="warning"']
      receiver: slack-default
      mute_time_intervals: [night]

time_intervals:
  - name: night
    time_intervals:
      - times: [{start_time: '22:00', end_time: '24:00'}]

inhibit_rules:
  - source_matchers: ['severity="critical"', 'alertname="NodeDown"']
    target_matchers: ['severity="warning"']
    equal: ['node', 'cluster']

receivers:
  - name: "null"
  - name: pagerduty
    pagerduty_configs:
      - routing_key: '<events-v2-key>'
  - name: slack-db
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/XXX'
        channel: '#db-alerts'
        send_resolved: true
  - name: slack-default
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/XXX'
        channel: '#alerts'
```

| ⚠️ Устарело | Сейчас |
| :--- | :--- |
| `match:` / `match_re:` в маршрутах | `matchers: ['label="v"', 'label=~"re"']` |
| `source_match` / `target_match` | `source_matchers` / `target_matchers` |
| `mute_time_intervals:` на верхнем уровне | `time_intervals:` (ссылки из маршрута — те же) |

## amtool

| Задача | Команда |
| :--- | :--- |
| Проверить конфиг (и шаблоны) | `amtool check-config alertmanager.yml` |
| Дерево маршрутов | `amtool config routes show --config.file=alertmanager.yml` |
| Куда уйдёт алерт с такими лейблами | `amtool config routes test --config.file=alertmanager.yml severity=critical team=db` |
| То же, с проверкой в CI | `... routes test --verify.receivers=pagerduty severity=critical` |
| Адрес Alertmanager по умолчанию | `--alertmanager.url=http://localhost:9093` или `~/.config/amtool/config.yml` |
| Активные алерты | `amtool alert query` (`alertname=~"Node.*"`) |
| Послать тестовый алерт | `amtool alert add alertname=Test severity=warning --annotation=summary="test"` |
| Silence на 2 часа | `amtool silence add instance="server-1" -d 2h -c "замена диска" -a "$USER"` |
| Список / снять silence | `amtool silence query` / `amtool silence expire <id>` |
| Снять все silences ⚠️ | `amtool silence expire $(amtool silence query -q)` |
| Состояние кластера | `amtool cluster show` |
| Отрендерить шаблон | `amtool template render --template.glob='tmpl/*.tmpl' --template.text='{{ template "slack.title" . }}'` |
| Проверка в Docker | `docker run --rm --entrypoint amtool -v "$PWD:/w:ro" prom/alertmanager check-config /w/alertmanager.yml` |

## HA и порты

| Параметр | Значение |
| :--- | :--- |
| HTTP API / UI | 9093 |
| Gossip-кластер | 9094 TCP+UDP (`--cluster.listen-address`, `--cluster.peer`) |
| Prometheus → Alertmanager | слать во **все** реплики, не через балансировщик |
| Split-brain | дубли уведомлений, не потеря (at-least-once) |
| Prometheus Operator | `AlertmanagerConfig` CRD на namespace команды |

## Хороший алерт

| Правило | Пример |
| :--- | :--- |
| Алерт по симптому, не по причине | error rate / latency SLO, а не «CPU 80%» |
| Каждому алерту — runbook | `annotations.runbook_url` |
| Не класть уникальные значения в лейблы | `timestamp`, `request_id` → в annotations |
| Dead man's switch | `Watchdog` (`vector(1)`) всегда Firing → внешний heartbeat |
| `send_resolved` | slack/email — дефолт `false`, webhook/pagerduty — `true` |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| Алерт Firing в Prometheus, уведомления нет | `amtool config routes test`, silences, inhibit, `/api/v2/status` |
| 100 писем вместо одного | `group_by` с уникальным лейблом или `...` |
| Дубли от каждой реплики | gossip 9094 закрыт, `amtool cluster show` |
| Алерт «мигает» | нет `for:`, короткое окно `rate()` |
| Тишина ночью при реальной аварии | забытый silence, `mute_time_intervals`, упал Watchdog-приёмник |

> Проверка: конфиг выше и `alertmanager-full.yaml` прошли
> `amtool check-config`, маршруты — `amtool config routes test`,
> подкоманды и флаги сверены с `amtool --help-long`
> (prom/alertmanager:v0.33.1); `alert add/query`, `silence add/query/
> expire`, `cluster show` — против запущенного Alertmanager в Docker;
> не проверено: `template render`, отправка в Slack/PagerDuty.
