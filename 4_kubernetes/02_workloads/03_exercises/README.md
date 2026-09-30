# Упражнения — Workloads

Стенд: 🐳 Tier 1 — kind кластер (`kind create cluster --name lab`)

## 01 — Deployment с rolling update

**Задача:** Создать Deployment с 3 репликами nginx. Настроить readinessProbe и livenessProbe. Обновить образ и проследить за rolling update. Откатить к предыдущей версии.

```bash
cd 01_deployment_rolling_update/
# TODO: написать deployment.yaml
kubectl apply -f deployment.yaml
kubectl rollout status deployment/nginx
kubectl set image deployment/nginx nginx=nginx:1.25
kubectl rollout undo deployment/nginx
```

## 02 — StatefulSet с PVC

**Задача:** Задеплоить PostgreSQL через StatefulSet. Создать данные. Удалить Pod и убедиться, что данные сохранились после перезапуска.

## 03 — DaemonSet + tolerations

**Задача:** Создать DaemonSet который запускается на всех нодах включая control-plane. Проверить что Pod создан на каждой ноде.

## 04 — CronJob

**Задача:** Создать CronJob который раз в минуту пишет timestamp в лог. Убедиться что старые Job'ы очищаются (successfulJobsHistoryLimit).

## 05 — QoS и eviction

**Задача:** Создать три Pod с разными QoS классами (Guaranteed, Burstable, BestEffort). Симулировать memory pressure. Проверить порядок выселения.
