# Workloads — шпаргалка

Подробности и объяснения — в
[workloads.md](./01_theory/workloads.md). ⚠️ — опасная команда или
частая ловушка.

## Какой контроллер выбрать

| Задача | Контроллер |
| :--- | :--- |
| Stateless-сервис (веб, API) | Deployment |
| БД, Kafka, кворумные системы: стабильные имена и свой диск | StatefulSet + headless Service |
| Агент на каждой ноде (логи, метрики, CNI) | DaemonSet |
| Разовая задача до успешного завершения (миграция) | Job |
| Задача по расписанию | CronJob |
| Голый Pod | только отладка — его никто не пересоздаст |

## Rollout Deployment

| Задача | Команда |
| :--- | :--- |
| Обновить образ | `kubectl set image deployment/web web=nginx:1.27-alpine` |
| Дождаться окончания (для CI) | `kubectl rollout status deployment/web --timeout=5m` |
| История ревизий | `kubectl rollout history deployment/web` |
| Детали ревизии | `kubectl rollout history deployment/web --revision=3` |
| Откатить на предыдущую / конкретную | `kubectl rollout undo deployment/web`<br>`kubectl rollout undo deployment/web --to-revision=3` |
| Пересоздать поды без смены образа | `kubectl rollout restart deployment/web` |
| Пауза / продолжить (пачка правок без rollout) | `kubectl rollout pause deployment/web` / `resume` |
| Подпись ревизии (вместо удалённого `--record`) | `kubectl annotate deployment/web kubernetes.io/change-cause="v1.27"` |
| ReplicaSet по версиям | `kubectl get rs -l app=web` |
| Масштабировать | `kubectl scale deployment/web --replicas=5` |
| Ждать готовности подов | `kubectl wait --for=condition=Ready pod -l app=web --timeout=120s` |

| Параметр | По умолчанию | Смысл |
| :--- | :--- | :--- |
| `strategy.type` | `RollingUpdate` | `Recreate` — сначала убить все старые |
| `maxUnavailable` | 25% (вниз) | сколько подов может не работать |
| `maxSurge` | 25% (вверх) | сколько подов сверх `replicas` |
| `revisionHistoryLimit` | 10 | сколько старых ReplicaSet хранить для `undo` |
| `progressDeadlineSeconds` | 600 | после — condition `Progressing=False` |
| `minReadySeconds` | 0 | сколько под должен быть Ready, чтобы считаться Available |

| Цель | Настройка |
| :--- | :--- |
| Без потери ёмкости | `maxUnavailable: 0`, `maxSurge: 1` |
| Blue/green «все новые, потом убить старые» (×2 ресурсов) | `maxUnavailable: 0`, `maxSurge: 100%` |
| Нельзя две версии одновременно | `strategy.type: Recreate` (даунтайм) |

## Пробы

| Проба | Провал → | Когда нужна |
| :--- | :--- | :--- |
| `startupProbe` | рестарт контейнера; остальные пробы ждут её успеха | медленный старт |
| `livenessProbe` | рестарт контейнера (kubelet) | зависание без выхода процесса |
| `readinessProbe` | под `Ready=False`, адрес убирается из EndpointSlice | временная неготовность |

| Поле пробы | По умолчанию |
| :--- | :--- |
| `periodSeconds` | 10 |
| `timeoutSeconds` | 1 |
| `failureThreshold` | 3 |
| `successThreshold` | 1 (для liveness/startup только 1) |
| `initialDelaySeconds` | 0 |

```yaml
startupProbe:            # до 30 × 10s = 5 мин на старт
  httpGet: {path: /healthz, port: 8080}
  failureThreshold: 30
  periodSeconds: 10
readinessProbe:
  httpGet: {path: /ready, port: 8080}
  periodSeconds: 5
livenessProbe:           # не проверять в ней зависимости (БД)!
  httpGet: {path: /healthz, port: 8080}
```

## StatefulSet, DaemonSet, Job, CronJob

| Задача | Команда / поле |
| :--- | :--- |
| DNS-имя пода StatefulSet | `<pod>.<headless-svc>.<ns>.svc.cluster.local` (`db-1.db.prod.svc...`) |
| Порядок запуска | `podManagementPolicy: OrderedReady` (по умолчанию) / `Parallel` |
| PVC на каждый под | `volumeClaimTemplates` → PVC `<tmpl>-<sts>-<N>` |
| Обновление StatefulSet по частям | `updateStrategy.rollingUpdate.partition: N` |
| Обновление DaemonSet | `kubectl rollout status ds/node-exporter -n monitoring` |
| DaemonSet на control-plane ноды | toleration `node-role.kubernetes.io/control-plane:NoSchedule` |
| Запустить CronJob вручную | `kubectl create job manual-1 --from=cronjob/backup` |
| Остановить CronJob | `kubectl patch cronjob backup -p '{"spec":{"suspend":true}}'` |
| Дождаться Job | `kubectl wait --for=condition=Complete job/migrate --timeout=10m` |
| Логи Job | `kubectl logs job/migrate` |

| Поле Job/CronJob | По умолчанию | Смысл |
| :--- | :--- | :--- |
| `backoffLimit` | 6 | ретраев до `Failed` |
| `activeDeadlineSeconds` | — | жёсткий таймаут Job |
| `ttlSecondsAfterFinished` | — | автоудаление завершённой Job |
| `restartPolicy` | — (обязательно `Never`/`OnFailure`) | `Always` для Job нельзя |
| `concurrencyPolicy` | `Allow` | `Forbid` — пропустить, `Replace` — убить старую |
| `startingDeadlineSeconds` | — | сколько можно опоздать с запуском |
| `successfulJobsHistoryLimit` / `failedJobsHistoryLimit` | 3 / 1 | хранимые Job |

## Pod: внутренности

| Задача | Команда |
| :--- | :--- |
| Init-контейнеры и их статус | `kubectl get pod web-0 -o jsonpath='{.status.initContainerStatuses[*].state}'` |
| Причина прошлого падения | `kubectl get pod web-0 -o jsonpath='{.status.containerStatuses[*].lastState}'` |
| QoS-класс | `kubectl get pod web-0 -o jsonpath='{.status.qosClass}'` |
| Владелец пода | `kubectl get pod web-0 -o jsonpath='{.metadata.ownerReferences[*].kind}'` |
| Рестарты по всем подам | `kubectl get pods --sort-by='.status.containerStatuses[0].restartCount'` |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| Rollout завис, старые поды живы | новые не Ready: `describe pod`, `logs --previous`; `undo` |
| `CrashLoopBackOff` | `logs --previous`, `lastState.terminated.reason` (`OOMKilled`, exit code) |
| `Init:0/1` долго | `kubectl logs <pod> -c <init>` |
| DaemonSet не на всех нодах | taints нод vs tolerations, `nodeSelector` |
| StatefulSet `db-1` не стартует | `db-0` не Ready (OrderedReady), PVC в `Pending` |
| CronJob не запускается | `suspend`, `concurrencyPolicy: Forbid`, `startingDeadlineSeconds` |
| Job бесконечно пересоздаёт поды | `backoffLimit`, `restartPolicy` |

## Ловушки

- ⚠️ PVC в Deployment с несколькими репликами — один диск на всех;
  для БД нужен StatefulSet.
- ⚠️ Scale down StatefulSet не удаляет PVC — данные остаются, чистить вручную.
- ⚠️ Liveness, зависящая от БД, перезапустит все поды при сбое БД.
- Init-контейнеры идут строго по очереди; исключение — native sidecar
  (`restartPolicy: Always` в `initContainers`), он работает рядом с
  приложением.
- `--record` у kubectl удалён — причину ревизии пишут аннотацией
  `kubernetes.io/change-cause`.

> Проверка: команды сверены с `kubectl <cmd> --help` (v1.34.1),
> rollout/undo/history, `create job --from`, `wait`, jsonpath и
> дефолты полей (`kubectl explain`, созданные объекты) прогнаны на
> временном kind-кластере; не проверено: —.
