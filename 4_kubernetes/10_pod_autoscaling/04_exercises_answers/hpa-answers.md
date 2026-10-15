# Ответы — Pod Autoscaling (HPA/KEDA)

Команды выполняются из каталога `10_pod_autoscaling/03_exercises/` на
kind-кластере с metrics-server (см. начало
[`../03_exercises/README.md`](../03_exercises/README.md)). Манифесты:
- [`hpa-answer.yaml`](./hpa-answer.yaml) — Deployment с `requests` + HPA
  (декларативный вариант упражнения 01);
- [`keda-redis-answer.yaml`](./keda-redis-answer.yaml) — Redis, консьюмер
  и `ScaledObject` для упражнения 03.

## Упражнение 01 — HPA на CPU

```bash
kubectl create deployment myapp --image=nginx --replicas=2
kubectl set resources deployment myapp --requests=cpu=50m --limits=cpu=100m
kubectl expose deployment myapp --port=80
kubectl apply -f ../02_examples/hpa.yaml

kubectl run load-gen --image=busybox --restart=Never -- \
  /bin/sh -c "while true; do wget -q -O- http://myapp >/dev/null; done"

kubectl get hpa myapp -w
```

Ожидаемый вывод (примерно так, обновление раз в 15-30 секунд):

```text
NAME    REFERENCE          TARGETS              MINPODS   MAXPODS   REPLICAS
myapp   Deployment/myapp   cpu: <unknown>/50%   2         10        2
myapp   Deployment/myapp   cpu: 50%/50%         2         10        2
myapp   Deployment/myapp   cpu: 63%/50%         2         10        3
myapp   Deployment/myapp   cpu: 42%/50%         2         10        3
```

Почему так: первые ~минуту метрик ещё нет (`<unknown>`), затем HPA
считает `ceil(2 × 63/50) = 3`. При 50% ровно реплики не добавляются —
у HPA есть допуск 10% вокруг цели. После `kubectl delete pod load-gen`
реплики вернутся к 2 только через 5 минут — окно стабилизации
`scaleDown` из `hpa.yaml`.

## Упражнение 02 — Проверить требование resources.requests

```bash
kubectl create deployment myapp-norequests --image=nginx --replicas=2
kubectl autoscale deployment myapp-norequests --cpu-percent=50 --min=1 --max=5
kubectl get hpa myapp-norequests
kubectl describe hpa myapp-norequests | grep -i "missing request"
```

Ожидаемый вывод (примерно так):

```text
NAME               REFERENCE                     TARGETS              MINPODS   MAXPODS   REPLICAS
myapp-norequests   Deployment/myapp-norequests   cpu: <unknown>/50%   1         5         2
  ScalingActive  False  FailedGetResourceMetric  the HPA was unable to compute the replica count: failed to get cpu utilization: missing request for cpu in container nginx of Pod ...
```

Почему так: `Utilization` — это потребление в процентах от
`requests.cpu`. Без `requests` знаменатель не определён, HPA пишет
`missing request for cpu` и не масштабирует вовсе (ни вверх, ни вниз).
Лечится `kubectl set resources ... --requests=cpu=...` или целью типа
`AverageValue` (абсолютные милликоры), которой `requests` не нужны.

## Упражнение 03 — KEDA: scale-to-zero

Вместо Kafka — Redis List: в kind его проще поднять, механика та же
(KEDA смотрит на длину очереди).

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm install keda kedacore/keda --namespace keda --create-namespace --wait

kubectl apply -f ../04_exercises_answers/keda-redis-answer.yaml
kubectl get scaledobject myapp-consumer
kubectl get deploy myapp-consumer
kubectl get hpa keda-hpa-myapp-consumer

# Положить 30 сообщений и смотреть на реплики
kubectl exec deploy/redis -- sh -c \
  'for i in $(seq 1 30); do redis-cli RPUSH orders "order-$i" >/dev/null; done'
kubectl get deployment myapp-consumer -w
```

Ожидаемый вывод (примерно так):

```text
NAME             SCALETARGETKIND      MIN   MAX   READY   ACTIVE   TRIGGERS
myapp-consumer   apps/v1.Deployment   0     5     True    False    redis
NAME             READY   UP-TO-DATE   AVAILABLE
myapp-consumer   0/0     0            0
NAME                      REFERENCE                   TARGETS             MINPODS   MAXPODS   REPLICAS
keda-hpa-myapp-consumer   Deployment/myapp-consumer   <unknown>/5 (avg)   1         5         0
myapp-consumer   4/4     4            4
myapp-consumer   5/5     5            5
myapp-consumer   0/0     0            0
```

Почему так: пока очередь пуста, `ScaledObject` неактивен (`ACTIVE
False`) и реплик 0. При появлении сообщений KEDA сам поднимает
Deployment 0 → 1, дальше созданный им HPA `keda-hpa-myapp-consumer`
масштабирует по формуле `ceil(длина списка / listLength)`. Когда очередь
пустеет, через `cooldownPeriod` (30 с) KEDA снова опускает до 0 — этого
HPA сам не умеет (`MINPODS 1`).

Уборка:

```bash
kubectl delete -f ../04_exercises_answers/keda-redis-answer.yaml
helm uninstall keda -n keda
kubectl delete pod load-gen
kubectl delete hpa myapp myapp-norequests
kubectl delete deployment myapp myapp-norequests
kubectl delete service myapp
```
