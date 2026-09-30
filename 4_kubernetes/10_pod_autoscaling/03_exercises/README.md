# Упражнения — Pod Autoscaling (HPA/KEDA)

Стенд: 🐳 Tier 1 — kind (нужен `metrics-server`, в kind не ставится по умолчанию)

```bash
kind create cluster --name autoscaling-lab

# metrics-server в kind требует отключить проверку TLS у kubelet (самоподписанные серты)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type=json \
  -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl top nodes   # должно заработать через 30-60 секунд
```

## 01 — HPA на CPU

**Задача:** Развернуть под с `resources.requests.cpu`, применить `hpa.yaml`, нагрузить CPU и увидеть автоскейлинг.

```bash
kubectl create deployment myapp --image=nginx --replicas=2
kubectl set resources deployment myapp --requests=cpu=50m --limits=cpu=100m

# TODO: применить ../02_examples/hpa.yaml (target Deployment: myapp)
kubectl apply -f ../02_examples/hpa.yaml

# Сгенерировать нагрузку
kubectl run load-gen --image=busybox --restart=Never -- \
  /bin/sh -c "while true; do wget -q -O- http://myapp; done"

kubectl get hpa myapp -w   # смотреть как растут REPLICAS
```

## 02 — Проверить требование resources.requests

**Задача:** Убедиться, что HPA не работает без `requests.cpu`.

```bash
kubectl create deployment myapp-norequests --image=nginx --replicas=2
kubectl autoscale deployment myapp-norequests --cpu-percent=50 --min=1 --max=5

kubectl get hpa myapp-norequests
# TARGETS должен показывать <unknown>/50% — TODO: объясни почему
```

## 03 — KEDA: scale-to-zero

**Задача:** Поставить KEDA, развернуть consumer с `ScaledObject`, убедиться что при отсутствии сообщений реплики падают до 0.

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm install keda kedacore/keda --namespace keda --create-namespace

# TODO: адаптировать ../02_examples/keda-scaledobject.yaml под локальный брокер
# (проще всего — Redis List trigger вместо Kafka для Tier 1 лабы)
kubectl apply -f ../02_examples/keda-scaledobject.yaml

kubectl get deployment myapp-consumer -w   # REPLICAS должен упасть до 0 при пустой очереди
```
