# Ответы — шаг 8 (Security)

Задание — [README.md](README.md). Кластер и образ — как в шаге 3
(`kind create cluster ... --name shortener`, `kind load docker-image
shortener:local --name shortener`). Команды — из папки `08_security/`.

## 1. Скан образа

```bash
docker build -t shortener:local ../app/
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image --severity HIGH,CRITICAL shortener:local
```

Ожидаемый вывод (примерно так, конкретные CVE зависят от даты):

```text
shortener:local (debian 13.x)
Total: 3 (HIGH: 3, CRITICAL: 0)
...
Python (python-pkg)
Total: 1 (HIGH: 1, CRITICAL: 0)
│ starlette │ CVE-XXXX-XXXXX │ HIGH │ 0.41.3 │ 0.47.2 │ ...
```

Почему так: находки в пакетах ОС закрываются пересборкой на свежем
`python:3.13-slim`, в Python-пакетах — обновлением пинов в
`requirements.txt` (часто транзитивных, как `starlette` под `fastapi`).
Уязвимость без исправленной версии — повод оценить применимость, а не
блокировать релиз вслепую. Подробнее — в
[10_devsecops/04_image_security](../../../10_devsecops/04_image_security/).

## 2. Pod Security Admission `restricted`

Файлы: [answers/namespace.yaml](answers/namespace.yaml) (метки PSA),
[answers/redis.yaml](answers/redis.yaml),
[answers/shortener.yaml](answers/shortener.yaml).

```bash
kubectl apply -f answers/namespace.yaml
kubectl apply -f ../03_kubernetes/manifests/shortener.yaml
kubectl apply -f answers/redis.yaml -f answers/shortener.yaml
kubectl -n shortener rollout status deployment/shortener
kubectl -n shortener get pods
```

Ожидаемый вывод (примерно так):

```text
namespace/shortener configured
Warning: would violate PodSecurity "restricted:latest":
allowPrivilegeEscalation != false (container "shortener" must set
securityContext.allowPrivilegeEscalation=false), unrestricted capabilities
..., runAsNonRoot != true ..., seccompProfile ...
deployment.apps/shortener configured
...
deployment "shortener" successfully rolled out
NAME                         READY   STATUS    RESTARTS   AGE
redis-6d4b7c9f8d-x2kqp       1/1     Running   0          40s
shortener-5f7d9c6b8-9tq4m    1/1     Running   0          35s
shortener-5f7d9c6b8-lw2vj    1/1     Running   0          35s
```

Почему так: старый манифест PSA предупреждает и не даёт создать поды
(enforce), исправленные проходят. Неочевидные места:
`runAsUser: 1000` нужен, потому что `USER appuser` в Dockerfile задан
именем, и kubelet не может проверить `runAsNonRoot` по имени; у Redis
образ стартует от root, поэтому `runAsUser: 999` (пользователь `redis`);
при `readOnlyRootFilesystem` записываемые пути (`/data` у Redis, `/tmp`
у приложения) вынесены в `emptyDir`.

## 3. NetworkPolicy

Файл: [answers/networkpolicy.yaml](answers/networkpolicy.yaml).

```bash
kubectl apply -f answers/networkpolicy.yaml
kubectl run probe -n default --rm -i --restart=Never --image=redis:7-alpine \
  -- redis-cli -h redis.shortener.svc.cluster.local -t 3 ping
kubectl -n shortener exec deploy/shortener -- \
  python -c "import redis; print(redis.Redis(host='redis').ping())"
```

Ожидаемый вывод (примерно так):

```text
networkpolicy.networking.k8s.io/default-deny-ingress created
networkpolicy.networking.k8s.io/redis-from-shortener created
networkpolicy.networking.k8s.io/shortener-http created
Could not connect to Redis at redis.shortener.svc.cluster.local:6379:
Connection timed out
True
```

Почему так: политики аддитивны — default deny закрывает весь ingress,
следующие две открывают только нужное. Важно: объекты NetworkPolicy
применяет CNI; если CNI их не поддерживает, `apply` пройдёт, но `probe`
достучится до Redis. Тогда кластер нужен с CNI, который умеет политики
(например, Calico) — см.
[10_devsecops/03_network_policy](../../../10_devsecops/03_network_policy/).

## 4. RBAC для CI

Файл: [answers/ci-deployer-rbac.yaml](answers/ci-deployer-rbac.yaml).

```bash
kubectl apply -f answers/ci-deployer-rbac.yaml
SA=system:serviceaccount:shortener:ci-deployer
kubectl auth can-i patch deployments -n shortener --as=$SA
kubectl auth can-i delete deployments -n shortener --as=$SA
kubectl auth can-i get secrets -n shortener --as=$SA
kubectl auth can-i patch deployments -n default --as=$SA
kubectl -n shortener create token ci-deployer --duration=1h
```

Ожидаемый вывод (примерно так):

```text
serviceaccount/ci-deployer created
role.rbac.authorization.k8s.io/ci-deployer created
rolebinding.rbac.authorization.k8s.io/ci-deployer created
yes
no
no
no
eyJhbGciOiJSUzI1NiIsImtpZCI6...
```

Почему так: `kubectl set image` — это `patch` Deployment, а
`rollout status` читает Deployment и его ReplicaSet (`get/list/watch`).
Role (не ClusterRole) ограничивает права одним namespace. Токен из
`create token` кладётся в kubeconfig для переменной `KUBECONFIG` шага 5
вместо админского.

```bash
kind delete cluster --name shortener
```
