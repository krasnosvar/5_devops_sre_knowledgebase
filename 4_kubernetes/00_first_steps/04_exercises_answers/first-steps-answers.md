# Ответы — Первые шаги в Kubernetes

Все команды выполняются из каталога `4_kubernetes/00_first_steps/`.
Имена подов, IP и время в выводе у вас будут другими.

## Упражнение 1 — Поднять кластер и разобраться с контекстом

```bash
kind create cluster --name first --config 02_examples/kind-config.yaml
kubectl config current-context
kubectl get nodes -o wide
kubectl get pods -n kube-system
```

Ожидаемый вывод (примерно так):

```text
kind-first
NAME                  STATUS   ROLES           AGE   VERSION   INTERNAL-IP ...
first-control-plane   Ready    control-plane   60s   v1.3x.x   172.18.0.3  ...
first-worker          Ready    <none>          45s   v1.3x.x   172.18.0.2  ...
first-worker2         Ready    <none>          45s   v1.3x.x   172.18.0.4  ...
NAME                                          READY   STATUS    RESTARTS   AGE
coredns-xxxxxxxxxx-xxxxx                      1/1     Running   0          60s
etcd-first-control-plane                      1/1     Running   0          60s
kube-apiserver-first-control-plane            1/1     Running   0          60s
...
```

Почему так: kind дописал в `~/.kube/config` (или в файл из
`KUBECONFIG`) кластер, пользователя и контекст `kind-first` и сделал
его текущим. Компоненты control plane видны как поды в `kube-system`,
потому что kind (через kubeadm) запускает их как static pods.

## Упражнение 2 — Голый Pod

```bash
kubectl apply -f 02_examples/pod.yaml
kubectl wait --for=condition=Ready pod/hello --timeout=120s
kubectl get pod hello -o wide
kubectl exec hello -- nginx -v
kubectl logs hello --tail=3
kubectl delete pod hello
kubectl get pods
```

Ожидаемый вывод (примерно так):

```text
pod/hello created
pod/hello condition met
NAME    READY   STATUS    RESTARTS   AGE   IP           NODE           ...
hello   1/1     Running   0          10s   10.244.2.2   first-worker2  ...
nginx version: nginx/1.27.5
... start worker processes
pod "hello" deleted
No resources found in default namespace.
```

Почему так: у голого пода нет владельца-контроллера, поэтому после
удаления его никто не пересоздаёт.

## Упражнение 3 — Deployment пересоздаёт поды

```bash
kubectl apply -f 02_examples/deployment.yaml
kubectl rollout status deployment/web
kubectl get pods -l app=web
kubectl delete pod "$(kubectl get pods -l app=web -o name | head -1 | cut -d/ -f2)"
kubectl get pods -l app=web
kubectl scale deployment web --replicas=4
kubectl get pods -l app=web
kubectl scale deployment web --replicas=2
kubectl get replicaset -l app=web
kubectl get pod -l app=web -o jsonpath='{.items[0].metadata.ownerReferences[0].kind}{"/"}{.items[0].metadata.ownerReferences[0].name}{"\n"}'
```

Ожидаемый вывод (примерно так):

```text
deployment "web" successfully rolled out
NAME                   READY   STATUS    RESTARTS   AGE
web-766ff4db78-5m9dj   1/1     Running   0          10s
web-766ff4db78-qc2zz   1/1     Running   0          10s
pod "web-766ff4db78-5m9dj" deleted
NAME                   READY   STATUS              RESTARTS   AGE
web-766ff4db78-4pkt2   0/1     ContainerCreating   0          1s
web-766ff4db78-qc2zz   1/1     Running             0          28s
...
NAME             DESIRED   CURRENT   READY   AGE
web-766ff4db78   2         2         2       1m
ReplicaSet/web-766ff4db78
```

Почему так: подами владеет ReplicaSet (им управляет Deployment).
Контроллер увидел, что подов меньше, чем `replicas`, и создал новый.

## Упражнение 4 — Service и доступ к приложению

```bash
kubectl apply -f 02_examples/service.yaml
kubectl get svc web
kubectl get endpointslices -l kubernetes.io/service-name=web
kubectl run tmp --rm -i --restart=Never --image=busybox:1.36 -- \
  wget -qO- http://web
```

Во втором терминале:

```bash
kubectl port-forward svc/web 8080:80
```

В первом терминале:

```bash
curl -s localhost:8080 | grep '<title>'
```

Ожидаемый вывод (примерно так):

```text
NAME   TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
web    ClusterIP   10.96.32.168   <none>        80/TCP    5s
NAME        ADDRESSTYPE   PORTS   ENDPOINTS               AGE
web-r9m4j   IPv4          80      10.244.2.3,10.244.1.2   5s
<!DOCTYPE html>
...
<title>Welcome to nginx!</title>
```

Почему так: Service выбирает поды по `selector: app: web`, а их IP
попадают в EndpointSlice. Имя `web` резолвит CoreDNS внутри кластера;
снаружи доступ есть только через port-forward (туннель к одному поду).

## Упражнение 5 — Сгенерировать манифест, а не писать руками

```bash
kubectl create deployment api --image=nginx:1.27-alpine --replicas=3 \
  --dry-run=client -o yaml > /tmp/api.yaml
cat /tmp/api.yaml
kubectl explain deployment.spec.revisionHistoryLimit
kubectl apply -f /tmp/api.yaml --dry-run=server
kubectl apply -f /tmp/api.yaml
kubectl get deployment api
kubectl delete -f /tmp/api.yaml
```

Ожидаемый вывод (примерно так):

```text
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: api
  name: api
spec:
  replicas: 3
...
FIELD: revisionHistoryLimit <integer>
DESCRIPTION:
    The number of old ReplicaSets to retain to allow rollback. ...
    Defaults to 10.
deployment.apps/api created (server dry run)
deployment.apps/api created
NAME   READY   UP-TO-DATE   AVAILABLE   AGE
api    3/3     3            3           15s
deployment.apps "api" deleted
```

Почему так: client dry-run только печатает объект; server dry-run
прогоняет его через API-сервер (схема, admission), но не сохраняет.
`revisionHistoryLimit` — сколько старых ReplicaSet хранить для
`kubectl rollout undo`, по умолчанию 10.

## Упражнение 6 — Уборка

```bash
kubectl delete -f 02_examples/service.yaml -f 02_examples/deployment.yaml
kind delete cluster --name first
kubectl config get-contexts
```

Ожидаемый вывод (примерно так):

```text
service "web" deleted
deployment.apps "web" deleted
Deleting cluster "first" ...
CURRENT   NAME   CLUSTER   AUTHINFO   NAMESPACE
```

Почему так: `kind delete cluster` удаляет контейнеры-ноды и сам
убирает свой контекст из kubeconfig. Удалять объекты перед удалением
кластера не обязательно — это для привычки убирать за собой.
