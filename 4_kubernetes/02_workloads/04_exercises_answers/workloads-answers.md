# Ответы — Workloads

Манифесты всех ответов лежат в
[workloads-answer.yaml](./workloads-answer.yaml); ниже — команды по
порядку и примерный вывод. Команды выполняются из каталога
`4_kubernetes/02_workloads/`. Имена подов, IP и время у вас будут
другими.

## Упражнение 01 — Deployment с rolling update

```bash
kubectl apply -f 04_exercises_answers/workloads-answer.yaml
kubectl rollout status deployment/webapp
kubectl set image deployment/webapp webapp=nginx:1.25-alpine
kubectl rollout status deployment/webapp
kubectl rollout history deployment/webapp
kubectl rollout undo deployment/webapp
kubectl rollout status deployment/webapp
kubectl get deployment webapp \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl get replicaset -l app=webapp
```

Ожидаемый вывод (примерно так):

```text
deployment "webapp" successfully rolled out
deployment.apps/webapp image updated
Waiting for deployment "webapp" rollout to finish: 1 out of 3 new replicas have been updated...
...
deployment "webapp" successfully rolled out
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
deployment.apps/webapp rolled back
deployment "webapp" successfully rolled out
nginx:1.24-alpine
NAME                DESIRED   CURRENT   READY   AGE
webapp-68695d6fcc   3         3         3       2m
webapp-6b6d88fc56   0         0         0       1m
```

Почему так: `maxSurge: 1, maxUnavailable: 0` — новый под создаётся
раньше, чем убивается старый, и старый уходит только после того, как
новый стал Ready. `undo` не "чинит" поды, а снова масштабирует старый
ReplicaSet, поэтому оба ReplicaSet остаются в истории.

## Упражнение 02 — StatefulSet с PVC

```bash
kubectl wait --for=condition=Ready pod/postgres-0 --timeout=180s
kubectl exec postgres-0 -- psql -U postgres \
  -c "CREATE TABLE notes(t text); INSERT INTO notes VALUES ('hello');"
kubectl get pvc
kubectl delete pod postgres-0
kubectl wait --for=condition=Ready pod/postgres-0 --timeout=180s
kubectl exec postgres-0 -- psql -U postgres -c "SELECT * FROM notes;"
```

Ожидаемый вывод (примерно так):

```text
pod/postgres-0 condition met
CREATE TABLE
INSERT 0 1
NAME              STATUS   VOLUME        CAPACITY   ACCESS MODES   STORAGECLASS   ...
data-postgres-0   Bound    pvc-cfef8bd5  1Gi        RWO            standard       ...
pod "postgres-0" deleted
pod/postgres-0 condition met
   t
-------
 hello
(1 row)
```

Почему так: PVC `data-postgres-0` создан из `volumeClaimTemplates` и
привязан к имени пода, а не к самому поду. Новый `postgres-0`
получает тот же PVC. Headless Service `postgres-headless` нужен
StatefulSet'у (поле `serviceName`) для DNS-имён вида
`postgres-0.postgres-headless`.

## Упражнение 03 — DaemonSet + tolerations

```bash
kubectl rollout status daemonset/node-logger
kubectl get pods -l app=node-logger -o wide
kubectl get nodes
kubectl logs -l app=node-logger --tail=1
```

Ожидаемый вывод (примерно так):

```text
daemon set "node-logger" successfully rolled out
NAME                READY   STATUS    ...   NODE
node-logger-bzfp6   1/1     Running   ...   lab-worker
node-logger-jk49p   1/1     Running   ...   lab-worker2
node-logger-zkr24   1/1     Running   ...   lab-control-plane
NAME                STATUS   ROLES           AGE
lab-control-plane   Ready    control-plane   10m
lab-worker          Ready    <none>          10m
lab-worker2         Ready    <none>          10m
node-logger-zkr24: Tue Oct 14 07:55:10 UTC 2026
...
```

Почему так: на control-plane ноде многонодового кластера висит taint
`node-role.kubernetes.io/control-plane:NoSchedule`; toleration с
`operator: Exists` разрешает поду туда попасть. Число подов равно
числу нод. В однонодовом kind taint с control-plane снят, поэтому
разницу там не видно.

## Упражнение 04 — CronJob

```bash
kubectl get cronjob timestamp
# подождать 3-4 минуты
kubectl get jobs
kubectl logs job/"$(kubectl get jobs -o jsonpath='{.items[-1].metadata.name}')"
```

Ожидаемый вывод (примерно так):

```text
NAME        SCHEDULE    TIMEZONE   SUSPEND   ACTIVE   LAST SCHEDULE   AGE
timestamp   * * * * *   <none>     False     0        <none>          5s
NAME                 STATUS     COMPLETIONS   DURATION   AGE
timestamp-29866313   Complete   1/1           5s         110s
timestamp-29866314   Complete   1/1           3s         50s
2026-10-14T11:54:00Z
```

Почему так: `successfulJobsHistoryLimit: 2` — cronjob controller
удаляет старые завершённые Job (вместе с их подами), оставляя только
2 последних, сколько бы минут ни прошло.

## Упражнение 05 — QoS и eviction

```bash
for p in guaranteed burstable besteffort; do
  echo -n "qos-$p: "
  kubectl get pod "qos-$p" -o jsonpath='{.status.qosClass}{"\n"}'
done
for p in guaranteed burstable besteffort; do
  echo -n "qos-$p: "
  kubectl exec "qos-$p" -- cat /proc/1/oom_score_adj
done
```

Ожидаемый вывод (примерно так):

```text
qos-guaranteed: Guaranteed
qos-burstable: Burstable
qos-besteffort: BestEffort
qos-guaranteed: -997
qos-burstable: 999
qos-besteffort: 1000
```

Почему так: QoS-класс вычисляется из `resources` (requests == limits
→ Guaranteed, нет ничего → BestEffort, иначе Burstable). kubelet
выставляет процессам `oom_score_adj`: ядерный OOM killer при нехватке
памяти первым убьёт BestEffort (1000), последним — Guaranteed (-997);
у Burstable значение зависит от доли requests в памяти ноды. Eviction
со стороны kubelet при `MemoryPressure` сначала выбирает поды, чьё
потребление превышает requests (BestEffort — всегда), затем учитывает
priority и превышение над requests; Guaranteed выселяется последним.
Подробнее — [05_scheduling](../../05_scheduling/) §5.
