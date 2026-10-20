# Chaos Engineering — шпаргалка

Подробности и объяснения — в
[chaos_engineering.md](./01_theory/chaos_engineering.md). ⚠️ — опасная
команда или частая ловушка.

## Цикл эксперимента

| Шаг | Что сделать |
| :--- | :--- |
| 1. Steady state | метрика «нормы»: error rate, p95, RPS |
| 2. Гипотеза | «если упадёт X, checkout работает через fallback» |
| 3. Blast radius | staging или малая доля prod, один под / одна AZ |
| 4. Abort-условие | порог метрики, при котором эксперимент стоп |
| 5. Инъекция | под, нода, сеть, CPU/память, диск, DNS |
| 6. Наблюдение | дашборды открыты заранее |
| 7. Откат и вывод | система вернулась в норму? action items |

## Когда НЕ проводить

| Условие | Почему |
| :--- | :--- |
| Freeze перед релизом | риск без выигрыша |
| Идёт инцидент | смешаете причины |
| Нет observability | не увидите эффекта |
| Нет ограничения blast radius | эксперимент станет инцидентом |
| Нет быстрого rollback | не остановите вовремя |

## Инструменты: когда что

| Инструмент | Когда |
| :--- | :--- |
| `kubectl delete`, `tc`, `stress-ng` руками | разовая проверка, gameday |
| Chaos Mesh | CRD для k8s: pod/network/stress/IO/time chaos, расписания |
| LitmusChaos | CRD + каталог экспериментов, probes, ChaosCenter (UI) |
| AWS FIS / облачные | отказ AZ, инстансов, управляемых сервисов |

## Ручные инъекции

| Сбой | Команда |
| :--- | :--- |
| Убить под (graceful) ⚠️ | `kubectl delete pod -l app=myapp -n production` |
| Убить под жёстко, без SIGTERM-паузы ⚠️ | `kubectl delete pod -l app=myapp -n production --grace-period=0 --force` |
| Вывести ноду ⚠️ | `kubectl drain <node> --ignore-daemonsets --delete-emptydir-data` (вернуть: `kubectl uncordon <node>`) |
| CPU | `stress-ng --cpu 2 --cpu-load 80 --timeout 60s` |
| Память | `stress-ng --vm 1 --vm-bytes 500M --timeout 60s` |
| Диск I/O | `stress-ng --hdd 1 --hdd-bytes 1G --timeout 60s` |
| Задержка сети | `tc qdisc add dev eth0 root netem delay 200ms 50ms` |
| Задержка + потери | `tc qdisc change dev eth0 root netem delay 200ms 50ms loss 5%` |
| Ограничить полосу | `tc qdisc replace dev eth0 root netem rate 1mbit` |
| Что сейчас навешено | `tc qdisc show dev eth0` |
| Убрать netem | `tc qdisc del dev eth0 root` |
| Сломать DNS в поде ⚠️ | `kubectl exec -it mypod -- sh -c "echo 'nameserver 0.0.0.0' > /etc/resolv.conf"` |

⚠️ `tc` внутри пода требует `NET_ADMIN` и бинарь `tc` (iproute2) в
образе; запускать как `kubectl exec -it <pod> -- tc ...`.

## Chaos Mesh

| Задача | Команда |
| :--- | :--- |
| Репозиторий | `helm repo add chaos-mesh https://charts.chaos-mesh.org` |
| Установка (containerd) | `helm install chaos-mesh chaos-mesh/chaos-mesh -n chaos-mesh --create-namespace --set chaosDaemon.runtime=containerd --set chaosDaemon.socketPath=/run/containerd/containerd.sock` |
| Запустить эксперимент | `kubectl apply -f chaos.yaml` |
| Остановить ⚠️ сразу | `kubectl delete -f chaos.yaml` |
| Список | `kubectl get podchaos,networkchaos,stresschaos -A` |

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: delay-200ms
  namespace: production
spec:
  action: delay          # PodChaos: pod-kill / pod-failure
  mode: all              # one / all / fixed / fixed-percent
  selector:
    labelSelectors:
      app: nginx
  delay:
    latency: "200ms"
    jitter: "50ms"
  duration: "5m"
```

## LitmusChaos

| Задача | Команда |
| :--- | :--- |
| Репозиторий | `helm repo add litmuschaos https://litmuschaos.github.io/litmus-helm/` |
| Оператор + CRD | `helm install litmus-core litmuschaos/litmus-core -n litmus --create-namespace` |
| Каталог экспериментов | чарт `litmuschaos/kubernetes-chaos` |
| ChaosCenter (веб-UI) | чарт `litmuschaos/litmus` |
| Статус | `kubectl describe chaosengine <engine> -n <ns>` |
| Вердикт | `kubectl get chaosresult <engine>-<experiment> -n <ns> -o jsonpath='{.status.verdict}'` |
| Остановить | `kubectl delete chaosengine <engine> -n <ns>` |

```yaml
# фрагмент ChaosEngine (Litmus 3.x)
spec:
  engineState: active
  chaosServiceAccount: pod-delete-sa
  experiments:
    - name: pod-delete
      spec:
        probe:
          - name: check-nginx
            type: httpProbe
            httpProbe/inputs:
              url: http://nginx-service/health
              method:
                get:
                  criteria: ==
                  responseCode: "200"
            mode: Continuous
            runProperties:
              probeTimeout: 5s   # в 3.x — строки с единицами
              interval: 2s
              attempt: 1         # бывший retry
```

## Gameday (2–4 ч)

| Этап | Длительность | Содержание |
| :--- | :--- | :--- |
| Подготовка | 30 мин | гипотеза, blast radius, дашборды, on-call в курсе |
| Эксперимент | 60–90 мин | инъекция, наблюдение, записи |
| Rollback | — | убрать сбой, убедиться в восстановлении |
| Ретро | 30 мин | гипотеза подтвердилась? что сломалось неожиданно? |

> Проверка: `tc netem` (delay/loss/rate/del) и `stress-ng` 0.18
> выполнены в одноразовом контейнере; манифесты Chaos Mesh 2.8.4 и
> Litmus 3.31 сверены со схемами CRD из чартов; kubectl — `--help`
> v1.34.1; не проверено: установка чартов в кластер.
