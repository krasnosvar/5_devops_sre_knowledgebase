# Chaos Engineering

## Принципы

**Chaos Engineering** — дисциплина экспериментов над системой для повышения уверенности в её отказоустойчивости в production условиях.

Из Netflix Chaos Monkey принципов:
1. Сформулировать гипотезу о стабильном состоянии
2. Разнообразить реальные события (failures)
3. Проводить эксперименты в production (или staging максимально близком к prod)
4. Автоматизировать непрерывно

**Blast radius** — ограничить масштаб эксперимента. Начинать с малого.

## Что тестировать

**Infra failures:**
- Убить Pod, Node, AZ
- Перегрузить CPU/Memory
- Заполнить диск

**Network failures:**
- Latency между сервисами
- Packet loss
- DNS failure
- Отказ внешнего API

**Application failures:**
- Медленные ответы зависимостей
- Отказ БД
- Истощение connection pool

## LitmusChaos — для Kubernetes

```bash
# установить LitmusChaos
helm repo add litmuschaos https://litmuschaos.github.io/litmus-helm/
helm install chaos litmuschaos/litmus --namespace litmus --create-namespace
```

```yaml
# ChaosExperiment: убить Pod
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosExperiment
metadata:
  name: pod-delete
spec:
  definition:
    scope: Namespaced
    image: litmuschaos/go-runner:latest
    args:
      - -c
      - ./experiments -name pod-delete
    env:
      - name: TOTAL_CHAOS_DURATION
        value: "30"
      - name: CHAOS_INTERVAL
        value: "10"
      - name: FORCE
        value: "false"

---
# ChaosEngine: применить эксперимент к конкретному сервису
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: nginx-chaos
  namespace: production
spec:
  appinfo:
    appns: production
    applabel: "app=nginx"
    appkind: deployment

  # наблюдать за этими probe'ами во время эксперимента
  experiments:
    - name: pod-delete
      spec:
        probe:
          - name: check-nginx-response
            type: httpProbe
            httpProbe/inputs:
              url: http://nginx-service/health
              expectedResponseCode: "200"
            mode: Continuous
            runProperties:
              probeTimeout: 5
              interval: 2
              retry: 1
```

```bash
# запустить
kubectl apply -f chaos-engine.yaml

# статус
kubectl describe chaosengine nginx-chaos -n production
kubectl get chaosresult nginx-chaos-pod-delete -n production -o jsonpath='{.status.verdict}'

# очистить
kubectl delete chaosengine nginx-chaos -n production
```

## Простые эксперименты без специальных инструментов

```bash
# Убить Pod (проверить что k8s перезапустит и LB перенаправит трафик)
kubectl delete pod -l app=myapp -n production --grace-period=0

# CPU stress в Pod
kubectl exec -it mypod -- stress --cpu 4 --timeout 60

# Memory pressure (нужен stress-ng)
kubectl exec -it mypod -- stress-ng --vm 1 --vm-bytes 500M --timeout 60s

# Симулировать network latency через tc (нужен root + NET_ADMIN capability)
kubectl exec -it mypod -- tc qdisc add dev eth0 root netem delay 200ms 50ms

# Убрать latency
kubectl exec -it mypod -- tc qdisc del dev eth0 root

# Дать DNS сбой в Pod
kubectl exec -it mypod -- bash -c "echo 'nameserver 0.0.0.0' > /etc/resolv.conf"
```

## Gameday — запланированный chaos

Структура gameday (2-4 часа):

```
1. Подготовка (30 мин)
   - Определить гипотезу: "Если упадёт payments-v2, checkout продолжит работу через fallback"
   - Определить blast radius: только staging / 5% prod трафика
   - Убедиться что observability готова (Grafana дашборды открыты)
   - On-call готов

2. Эксперимент (60-90 мин)
   - Применить сбой
   - Наблюдать: error rate, latency, user impact
   - Документировать что происходит

3. Rollback
   - Убрать сбой
   - Убедиться что система восстановилась

4. Ретроспектива (30 мин)
   - Гипотеза подтвердилась? (да/нет)
   - Что сломалось неожиданно?
   - Action items
```

## Когда НЕ проводить chaos

- Перед релизом (freeze period)
- При активном инциденте
- Без observability (не видишь что происходит)
- Без blast radius ограничений
- Без возможности быстрого rollback
