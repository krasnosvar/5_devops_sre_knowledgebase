# Шаг 3 — Kubernetes

🐳 Tier 1 (kind/k3d) или 🖥 Tier 2 (реальные VM — см. шаг 4). Теория —
[4_kubernetes](../../../4_kubernetes/) (Workloads, Networking, Scheduling).

Для самого k8s проще и быстрее взять kind/k3d
([0_lab_setup/03_local_k8s](../../03_local_k8s/)) — реальный bootstrap кластера
через kubeadm на VM намеренно вынесен в шаг 4 (IaC), там он уместнее.

## Поднять локальный кластер и собрать образ внутрь него

```bash
cd ../03_local_k8s/02_examples/
kind create cluster --config kind-cluster.yaml --name shortener

cd ../../05_capstone_project/app/
docker build -t shortener:local .
kind load docker-image shortener:local --name shortener
```

## Применить манифесты

```bash
cd ../03_kubernetes/manifests/
kubectl apply -f namespace.yaml
kubectl apply -f redis.yaml -f shortener.yaml

kubectl -n shortener rollout status deployment/shortener
```

## Проверить

```bash
kubectl -n shortener port-forward svc/shortener 8000:8000 &
curl -s http://localhost:8000/health
curl -s -X POST http://localhost:8000/shorten -d '{"url":"https://example.com"}'
kill %1
```

## Что почувствовать на этом шаге

- `kubectl -n shortener get pods -w` во время `kubectl delete pod` одного
  из `shortener` — Deployment сам поднимет замену. Redis без
  Deployment/StatefulSet так не умеет сам себя вылечить на bare Linux/Docker.
- `readinessProbe`/`livenessProbe` в `shortener.yaml` — Service не пошлёт
  трафик на под, пока `/health` не ответит 200. Сравни с шагом 1, где
  ничего не проверяло готовность процесса перед тем как слать ему curl.
- Пока сознательно нет: Ingress, PersistentVolume для Redis (данные теряются
  при рестарте — это нормально для лабы), NetworkPolicy — они появятся
  в шаге 8 (Security), где это важно показать осознанно, а не по умолчанию.

```bash
kind delete cluster --name shortener
```
