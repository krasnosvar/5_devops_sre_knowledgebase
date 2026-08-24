# Alerting

## Хороший алерт vs плохой алерт

**Хороший алерт:**
- Требует немедленного действия (actionable)
- Указывает что делать (runbook URL)
- Алертит на симптом пользователя, а не на причину
- Не шумит (low false positive rate)

**Плохой алерт:**
- Алертит на что-то что можно проигнорировать
- Нет инструкции что делать
- Срабатывает при кратковременных спайках (нет `for: 5m`)
- Дублирует другой алерт

## Alertmanager — маршрутизация

```yaml
# alertmanager.yml
global:
  resolve_timeout: 5m
  slack_api_url: 'https://hooks.slack.com/services/...'

# Дерево маршрутизации
route:
  group_by: ['alertname', 'cluster', 'namespace']
  group_wait: 30s           # ждать 30с перед первой нотификацией (группировать)
  group_interval: 5m        # минимум между повторами для той же группы
  repeat_interval: 3h       # повторять если не resolved
  receiver: 'slack-default'

  routes:
    # SEV-1 → немедленно в PagerDuty
    - matchers:
        - severity = critical
      receiver: pagerduty
      continue: false       # не идти дальше по дереву

    # SEV-2 → Slack #alerts-prod
    - matchers:
        - severity = warning
        - env = production
      receiver: slack-production
      group_wait: 0s

    # Все остальные → Slack #alerts-dev
    - receiver: slack-default

receivers:
  - name: slack-production
    slack_configs:
      - channel: '#alerts-production'
        title: '{{ .CommonLabels.alertname }} [{{ .CommonLabels.severity | toUpper }}]'
        text: |
          {{ range .Alerts }}
          *Alert:* {{ .Labels.alertname }}
          *Service:* {{ .Labels.service }}
          *Summary:* {{ .Annotations.summary }}
          *Description:* {{ .Annotations.description }}
          *Runbook:* {{ .Annotations.runbook_url }}
          {{ end }}
        send_resolved: true

  - name: pagerduty
    pagerduty_configs:
      - service_key: 'YOUR_PD_KEY'
        description: '{{ .CommonLabels.alertname }}'
        severity: '{{ .CommonLabels.severity }}'

  - name: 'null'   # поглощать алерты без нотификации

# Подавление алертов
inhibit_rules:
  # Если есть critical — подавить warning для той же системы
  - source_matchers:
      - severity = critical
    target_matchers:
      - severity = warning
    equal: ['alertname', 'cluster', 'namespace']

  # Подавить алерты на down ноду если она в maintenace
  - source_matchers:
      - alertname = NodeMaintenance
    target_matchers:
      - instance =~ ".*"
    equal: ['instance']
```

## Силенсы — заглушить во время обслуживания

```bash
# создать silence на 2 часа для конкретного инстанса
amtool silence add \
  --alertmanager.url http://alertmanager:9093 \
  --author "ops-team" \
  --comment "Scheduled maintenance" \
  --duration 2h \
  'instance="web-1.example.com"'

# список активных silences
amtool silence query --alertmanager.url http://alertmanager:9093

# удалить silence
amtool silence expire <silence-id> --alertmanager.url http://alertmanager:9093
```

## Alert fatigue — как избежать

**Причины усталости от алертов:**
- Слишком низкий порог (мусорные алерты)
- Отсутствие `for:` (кратковременные спайки)
- Нет `inhibit_rules` (каскад из 50 алертов при одном сбое)
- Алерты без действия (нет runbook, нет ответственного)

**Что делать:**
```yaml
# 1. Всегда использовать for: (не алертить на мгновенные spike)
- alert: HighCPU
  expr: cpu_usage > 90
  for: 15m    # держаться 15 минут

# 2. Группировать алерты
route:
  group_by: ['alertname', 'cluster']  # один алерт на кластер, не один на pod

# 3. Использовать inhibit_rules
# 4. Регулярный review: если алерт срабатывает > 2 раз/неделю без action — убрать или исправить
# 5. Метрика: среднее время от алерта до action (MTTA)
```

## Prometheus alerting rules — best practices

```yaml
groups:
  - name: slo.critical
    rules:
      # Burn rate алерт (лучше threshold)
      - alert: HighBurnRate
        expr: |
          (
            rate(http_requests_total{status=~"5.."}[1h])
            / rate(http_requests_total[1h])
          ) > (14.4 * 0.001)   # 14.4x burn rate, SLO=99.9%
        for: 2m
        labels:
          severity: critical
          team: '{{ $labels.team }}'    # динамический label
        annotations:
          summary: 'Error budget burning fast for {{ $labels.service }}'
          description: |
            Error rate is {{ $value | humanizePercentage }}.
            At this rate, monthly budget will be exhausted in
            {{ div 30 (div $value 0.001) | humanizeDuration }}.
          runbook_url: 'https://runbooks.example.com/{{ $labels.alertname }}'
          dashboard_url: 'https://grafana.example.com/d/slo?var-service={{ $labels.service }}'
```
