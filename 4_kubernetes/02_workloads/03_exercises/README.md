# Упражнения — Workloads

Стенд: 🐳 Tier 1 — kind кластер. Для упражнения 03 нужен кластер из
нескольких нод (например,
[0_lab_setup/03_local_k8s/02_examples/kind-cluster.yaml](../../../0_lab_setup/03_local_k8s/02_examples/kind-cluster.yaml)):

```bash
kind create cluster --name lab --config ../../../0_lab_setup/03_local_k8s/02_examples/kind-cluster.yaml
```

Ответы: [04_exercises_answers/workloads-answers.md](../04_exercises_answers/workloads-answers.md)
(команды и ожидаемый вывод) и
[workloads-answer.yaml](../04_exercises_answers/workloads-answer.yaml)
(манифесты).

## 01 — Deployment с rolling update

**Задача:** Создать Deployment `webapp` с 3 репликами nginx. Настроить
readinessProbe и livenessProbe. Обновить образ и проследить за rolling
update. Откатить к предыдущей версии.

```bash
# написать свой deployment.yaml (Deployment webapp, контейнер webapp)
kubectl apply -f deployment.yaml
kubectl rollout status deployment/webapp
kubectl set image deployment/webapp webapp=nginx:1.25-alpine
kubectl rollout undo deployment/webapp
```

## 02 — StatefulSet с PVC

**Задача:** Задеплоить PostgreSQL через StatefulSet. Создать данные. Удалить
Pod и убедиться, что данные сохранились после перезапуска.

## 03 — DaemonSet + tolerations

**Задача:** Создать DaemonSet который запускается на всех нодах включая
control-plane. Проверить что Pod создан на каждой ноде.

## 04 — CronJob

**Задача:** Создать CronJob который раз в минуту пишет timestamp в лог.
Убедиться что старые Job'ы очищаются (successfulJobsHistoryLimit).

## 05 — QoS и eviction

**Задача:** Создать три Pod с разными QoS классами (Guaranteed,
Burstable, BestEffort). Проверить, какой класс назначил Kubernetes, и
определить порядок, в котором их будут убивать при нехватке памяти на
ноде: по `oom_score_adj` процессов и по правилам eviction kubelet.
Реально устраивать memory pressure на kind не обязательно: ноды kind
делят память хоста, и эксперимент может задеть другие процессы.
