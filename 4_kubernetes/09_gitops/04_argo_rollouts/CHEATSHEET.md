# Argo Rollouts — шпаргалка

Подробности и объяснения — в [argo_rollouts.md](./01_theory/argo_rollouts.md),
пример — [rollout-canary.yaml](./02_examples/rollout-canary.yaml).
⚠️ — опасная команда или частая ловушка. Команды — плагин
`kubectl argo rollouts`.

## Команды плагина

| Задача | Команда |
| :--- | :--- |
| Список rollout'ов | `kubectl argo rollouts list rollouts -n prod` |
| Дерево ReplicaSet/подов, шаг, вес — вживую | `kubectl argo rollouts get rollout myapp -n prod --watch` |
| Дождаться завершения (CI) | `kubectl argo rollouts status myapp -n prod --timeout 15m` |
| Выкатить новый образ | `kubectl argo rollouts set image myapp myapp=myapp:v2` |
| Пройти ручную паузу (`pause: {}`) | `kubectl argo rollouts promote myapp` |
| Пропустить все шаги и анализ ⚠️ | `kubectl argo rollouts promote myapp --full` |
| Прервать, вернуть трафик на stable | `kubectl argo rollouts abort myapp` |
| Повторить после abort | `kubectl argo rollouts retry rollout myapp` |
| Откатить на ревизию | `kubectl argo rollouts undo myapp --to-revision=3` |
| Поставить на паузу | `kubectl argo rollouts pause myapp` |
| Перезапустить поды | `kubectl argo rollouts restart myapp` |
| Проверить манифест | `kubectl argo rollouts lint -f rollout.yaml` |
| Веб-дашборд | `kubectl argo rollouts dashboard` (порт 3100) |
| Результаты анализа | `kubectl get analysisrun -n prod`, `kubectl describe analysisrun <name>` |

⚠️ После `abort` `spec.template` всё ещё новая версия: при выходе из
aborted rollout снова пойдёт на неё. Откат по-GitOps — `git revert`.

## Canary

```yaml
strategy:
  canary:
    analysis:                       # фоновый анализ на всём протяжении
      templates: [{templateName: success-rate}]
      startingStep: 1
    steps:
      - setWeight: 5
      - pause: {duration: 5m}
      - setWeight: 50
      - pause: {}                   # без duration — ждёт promote
```

| Шаг | Смысл |
| :--- | :--- |
| `setWeight: N` | доля трафика на новую версию (без mesh/ingress — доля подов) |
| `pause: {duration: 5m}` | ждать и идти дальше |
| `pause: {}` | ждать ручной `promote` |
| `analysis` в `steps` | анализ-шаг: блокирует, пока не завершится |
| `trafficRouting` (`nginx`, `istio`, `alb`, ...) | точный процент запросов вместо пропорции подов |

## AnalysisTemplate

```yaml
metrics:
  - name: error-rate
    interval: 1m
    successCondition: result[0] < 0.05
    failureLimit: 2                 # 3-я неудача (всего) — Failed
    provider:
      prometheus:
        address: http://prometheus.monitoring.svc:9090
        query: |
          sum(rate(http_requests_total{status=~"5.."}[1m]))
          / sum(rate(http_requests_total[1m]))
```

| Поле | Поведение |
| :--- | :--- |
| `successCondition` / `failureCondition` | выражение над `result` |
| `failureLimit` | сколько неудачных измерений терпеть всего (по умолчанию 0) |
| `count` | сколько измерений сделать (без него — пока идёт шаг/rollout) |
| `inconclusiveLimit` | лимит «ни да ни нет» до паузы |
| Анализ `Failed` | rollout `abort`: трафик на stable, статус `Degraded` |

## Blue/Green

| Поле | Смысл |
| :--- | :--- |
| `activeService` | Service с продакшен-трафиком |
| `previewService` | Service на новую версию для проверки |
| `autoPromotionEnabled: false` | ждать `promote` |
| `scaleDownDelaySeconds` | сколько держать старую версию после переключения (30 с) |
| `prePromotionAnalysis` / `postPromotionAnalysis` | анализ до/после переключения |

## Когда что

| Ситуация | Стратегия |
| :--- | :--- |
| Проверить на малой доле реальных пользователей | Canary + AnalysisTemplate |
| QA проверяет до первого боевого запроса | Blue/Green с `previewService` |
| Ресурсов кластера впритык | Canary (Blue/Green держит ×2 реплик) |
| Нужен мгновенный полный откат | Blue/Green |
| Только Ready-проверка, без метрик | обычный Deployment `RollingUpdate` |

## Симптом → куда смотреть

| Симптом | Причина / проверка |
| :--- | :--- |
| Rollout стоит `Paused` | `pause: {}` ждёт `promote` |
| `Degraded`, трафик на stable | анализ `Failed`: `kubectl describe analysisrun` |
| Вес 5%, а трафик делится по подам | нет `trafficRouting`: при 10 репликах 5% = 1 под (≈10%) |
| Анализ `Error` | недоступен Prometheus / запрос вернул пустой результат |
| Argo CD показывает `Suspended` | так Argo CD отображает Rollout на паузе |

> Проверка: подкоманды и флаги сверены с `kubectl-argo-rollouts --help`
> (образ `quay.io/argoproj/kubectl-argo-rollouts:v1.8.3`), YAML —
> `yamllint`; не проверено: поведение на живом кластере, значения по
> умолчанию полей — по документации.
