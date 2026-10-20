# Автоскейлинг подов — шпаргалка

Подробности и объяснения — в
[pod_autoscaling.md](./01_theory/pod_autoscaling.md).
⚠️ — опасная команда или частая ловушка.

## Когда что

| Задача | Инструмент |
| :--- | :--- |
| Больше реплик при росте CPU/памяти | HPA (`autoscaling/v2`) + metrics-server |
| Больше реплик по RPS, latency из Prometheus | HPA + Prometheus Adapter или KEDA (`prometheus` trigger) |
| По очереди (Kafka lag, SQS, RabbitMQ), scale-to-zero | KEDA `ScaledObject` |
| Подобрать `requests`/`limits` одному поду | VPA (`updateMode: "Off"` — только рекомендации) |
| Добавить ноды, когда подам негде жить | CA / Karpenter → [CHEATSHEET](../08_cluster_operations/02_node_autoscaling/CHEATSHEET.md) |

⚠️ HPA и VPA на одной метрике (CPU/RAM) одного объекта — гонка. Можно:
HPA по внешней метрике + VPA по памяти.

## Команды

| Задача | Команда |
| :--- | :--- |
| HPA одной командой | `kubectl autoscale deployment myapp --min=2 --max=10 --cpu=50%` |
| Состояние HPA | `kubectl get hpa myapp` (`TARGETS 75%/50%`, `<unknown>` — нет метрики) |
| Почему не скейлит | `kubectl describe hpa myapp` → `Conditions` (`AbleToScale`, `ScalingActive`, `ScalingLimited`) и `Events` |
| Следить | `kubectl get hpa myapp -w` |
| Метрики подов / нод | `kubectl top pods --containers` / `kubectl top nodes` |
| Жив ли Metrics API | `kubectl get apiservice v1beta1.metrics.k8s.io` |
| Сырые метрики | `kubectl get --raw /apis/metrics.k8s.io/v1beta1/namespaces/default/pods` |
| Кастомные / внешние метрики | `kubectl get --raw /apis/custom.metrics.k8s.io/v1beta1` / `.../external.metrics.k8s.io/v1beta1` |
| Рекомендации VPA | `kubectl describe vpa myapp` → `Recommendation` (`Target`, `Lower/Upper Bound`) |
| KEDA-объекты | `kubectl get scaledobject,scaledjob -A` |
| HPA, созданный KEDA | `kubectl get hpa keda-hpa-myapp-consumer` |
| Нагрузить для теста | `kubectl run load --rm -it --image=busybox:1.36 -- sh -c 'while true; do wget -qO- http://myapp; done'` |

## Формула и значения по умолчанию

```text
desiredReplicas = ceil(currentReplicas × currentMetric / targetMetric)
пример: ceil(4 × 100 / 50) = 8
```

| Параметр | Значение |
| :--- | :--- |
| Период опроса HPA | 15 с (`--horizontal-pod-autoscaler-sync-period`) |
| Допуск (не скейлить) | ±10% от цели (`tolerance`) |
| Stabilization window scale-up | 0 с |
| Stabilization window scale-down | 300 с |
| `Utilization` считается от | `requests` контейнера, не от CPU ноды |
| `minReplicas: 0` | только с alpha feature gate `HPAScaleToZero` |
| Опрос KEDA (`pollingInterval`) | 30 с; `cooldownPeriod` до 0 — 300 с |

## HPA с behavior

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: {name: myapp}
spec:
  scaleTargetRef: {apiVersion: apps/v1, kind: Deployment, name: myapp}
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource: {name: cpu, target: {type: Utilization, averageUtilization: 50}}
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies: [{type: Percent, value: 50, periodSeconds: 60}]
    scaleUp:
      policies: [{type: Pods, value: 4, periodSeconds: 60}]
```

| Тип метрики | Пример |
| :--- | :--- |
| `Resource` | CPU/память, `Utilization` (%) или `AverageValue` |
| `Pods` | среднее на под из custom metrics (RPS на под) |
| `Object` | метрика другого объекта (RPS Ingress) |
| `External` | вне кластера (длина очереди) |

## VPA и KEDA

| VPA `updateMode` | Поведение |
| :--- | :--- |
| `Off` | только рекомендации |
| `Initial` | ставит `requests` при создании пода |
| `Recreate` / `Auto` | выселяет под и создаёт с новыми `requests` |
| `InPlaceOrRecreate` | сначала in-place resize, иначе пересоздание (проверить версию VPA) |

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata: {name: myapp-consumer}
spec:
  scaleTargetRef: {name: myapp-consumer}
  minReplicaCount: 0
  maxReplicaCount: 20
  triggers:
    - type: kafka
      metadata: {bootstrapServers: "kafka.default.svc:9092", consumerGroup: myapp-group, topic: orders, lagThreshold: "50"}
```

## Симптом → куда смотреть

| Симптом | Причина / проверка |
| :--- | :--- |
| `TARGETS <unknown>/50%` | нет `requests.cpu` или не работает metrics-server |
| `FailedGetResourceMetric` в Events | metrics-server недоступен: `kubectl get apiservice v1beta1.metrics.k8s.io` |
| Нагрузка упала, реплики держатся 5 мин | так задумано: scale-down window 300 с |
| Реплики скачут, Argo CD `OutOfSync` | `replicas` в Git борется с HPA: убрать поле |
| Поды постоянно пересоздаются | VPA `Auto` + HPA на той же метрике |
| HPA на `maxReplicas`, а поды `Pending` | кончились ноды → node autoscaling |
| KEDA не поднимает с 0 | ошибка trigger/auth: `kubectl describe scaledobject`, логи `keda-operator` |
| Ручной `kubectl scale` откатывается | HPA/KEDA владеют `replicas` |

> Проверка: флаги `kubectl autoscale/top/get --raw` сверены с `--help`
> (v1.34.1, `--cpu=50%` вместо устаревшего `--cpu-percent`), YAML —
> `yamllint`; не проверено: поведение HPA/VPA/KEDA на кластере, дефолты
> KEDA — по документации.
