# Шедулинг и защита от вытеснений — шпаргалка

Подробности и объяснения — в
[scheduling.md](./01_theory/scheduling.md). ⚠️ — опасная команда или
частая ловушка.

## Когда что использовать

| Задача | Механизм |
| :--- | :--- |
| Под только на ноды с меткой (жёстко, просто) | `nodeSelector` |
| Жёстко/мягко на ноды с выражениями `In`, `NotIn`, `Exists` | `nodeAffinity` required / preferred |
| Не пускать чужие поды на ноду (GPU, infra) | `taint` на ноде + `tolerations` у пода |
| Выделенная нода: и не пускать чужих, и тянуть своих | taint + toleration **и** nodeAffinity |
| Реплики по зонам/нодам равномерно | `topologySpreadConstraints` |
| Не ставить две реплики на одну ноду | `podAntiAffinity` по `kubernetes.io/hostname` |
| Ставить рядом с другим подом (кэш) | `podAffinity` |
| Не дать drain уронить сервис | `PodDisruptionBudget` |
| Важный под должен вытеснить неважные | `PriorityClass` (preemption) |
| Потолок ресурсов на namespace | `ResourceQuota` |
| Дефолты и границы на контейнер | `LimitRange` |
| Пере-распределить уже запущенные поды | descheduler |

## Ноды: метки, taints, обслуживание

| Задача | Команда |
| :--- | :--- |
| Метки нод | `kubectl get nodes --show-labels`<br>`kubectl get nodes -L topology.kubernetes.io/zone` |
| Повесить метку | `kubectl label node node1 disktype=ssd` |
| Снять метку | `kubectl label node node1 disktype-` |
| Повесить taint | `kubectl taint nodes node1 gpu=true:NoSchedule` |
| Снять taint | `kubectl taint nodes node1 gpu=true:NoSchedule-` |
| Taints всех нод | `kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints[*].key` |
| Запретить новые поды | `kubectl cordon node1` / вернуть: `kubectl uncordon node1` |
| Вывести ноду в обслуживание ⚠️ | `kubectl drain node1 --ignore-daemonsets --delete-emptydir-data --timeout=10m` |
| Аллокация ресурсов ноды | `kubectl describe node node1` → `Allocated resources` |
| Реальное потребление (metrics-server) | `kubectl top nodes`; `kubectl top pods -A --sort-by=memory` |
| Почему под не встал | `kubectl describe pod <pod>` → `FailedScheduling: 0/3 nodes are available: ...` |
| Поды на конкретной ноде | `kubectl get pods -A --field-selector spec.nodeName=node1` |
| Все поды в `Pending` | `kubectl get pods -A --field-selector status.phase=Pending` |

| Эффект taint | Новые поды | Запущенные без toleration |
| :--- | :--- | :--- |
| `PreferNoSchedule` | по возможности не сюда | остаются |
| `NoSchedule` | не планируются | остаются |
| `NoExecute` | не планируются | выселяются (через `tolerationSeconds`, если задан) |

## Сниппеты

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - {key: disktype, operator: In, values: [ssd]}
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector: {matchLabels: {app: web}}
          topologyKey: kubernetes.io/hostname
tolerations:
  - {key: gpu, operator: Equal, value: "true", effect: NoSchedule}
  - key: node.kubernetes.io/unreachable     # быстрее failover (дефолт 300)
    operator: Exists
    effect: NoExecute
    tolerationSeconds: 30
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule        # мягко: ScheduleAnyway
    labelSelector: {matchLabels: {app: web}}
```

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata: {name: web}
spec:
  minAvailable: 2          # или maxUnavailable: 1 — не оба сразу
  selector: {matchLabels: {app: web}}
```

| Задача | Команда |
| :--- | :--- |
| Создать PDB | `kubectl create pdb web --selector=app=web --min-available=2` |
| Сколько сбоев разрешено сейчас | `kubectl get pdb` (колонка `ALLOWED DISRUPTIONS`) |
| Классы приоритета | `kubectl get priorityclass` |
| Создать класс | `kubectl create priorityclass critical --value=1000000 --description="ingress"` |
| Квота и использование | `kubectl describe resourcequota -n team-a` |
| Создать квоту | `kubectl create quota team-a --hard=requests.cpu=10,requests.memory=20Gi,pods=50 -n team-a` |
| LimitRange namespace | `kubectl describe limitrange -n team-a` |

## QoS и вытеснение

| QoS | Условие | `oom_score_adj` | Порядок убийства |
| :--- | :--- | :--- | :--- |
| Guaranteed | у всех контейнеров `requests == limits` по CPU и памяти | -997 | последними |
| Burstable | есть хоть один request/limit, но не Guaranteed | 2…999 (чем больше request, тем ниже) | между |
| BestEffort | нет ни requests, ни limits | 1000 | первыми |

| Событие | Кто | Почему | Сигнал |
| :--- | :--- | :--- | :--- |
| `OOMKilled` | ядро (cgroup) | контейнер превысил свой `limits.memory` | SIGKILL |
| Node-pressure eviction | kubelet | на ноде мало памяти/диска (`memory.available<100Mi` по умолчанию) | soft — с grace period, hard — сразу |
| API-eviction (drain) | API-сервер (Eviction API) | обслуживание ноды, уважает PDB | SIGTERM + `terminationGracePeriodSeconds` |
| Preemption | kube-scheduler | под с высшим приоритетом не помещается | SIGTERM |
| Taint `NoExecute` | taint-eviction controller (KCM) | нода `not-ready`/`unreachable` или ручной taint | удаление пода |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| `Insufficient cpu/memory` | считаются **requests**, не реальное потребление → `describe node` |
| `node(s) had untolerated taint` | tolerations пода vs `kubectl describe node \| grep Taints` |
| `didn't match Pod's node affinity/selector` | метки нод (`-L`), опечатка в ключе |
| `didn't match pod topology spread constraints` | мало зон/нод, `DoNotSchedule` → `ScheduleAnyway` |
| `drain` висит: `Cannot evict pod as it would violate the pod's disruption budget` | `kubectl get pdb`, `ALLOWED DISRUPTIONS = 0` |
| `exceeded quota` / `must specify requests.cpu` | `describe resourcequota`, добавить LimitRange с дефолтами |
| Поды распределены неравномерно со временем | scheduler решает один раз → descheduler |

## Ловушки

- ⚠️ PDB с `maxUnavailable: 0` (или `minAvailable` = числу реплик)
  блокирует drain навсегда — даже лишние реплики не помогут при
  `maxUnavailable: 0`.
- ⚠️ `drain` без `--ignore-daemonsets` не стартует, а поды с `emptyDir`
  требуют `--delete-emptydir-data` (данные теряются).
- PDB не защищает от падения ноды, OOM и kernel panic.
- `nodeName` в спеке пропускает scheduler целиком — анти-паттерн.
- `...IgnoredDuringExecution`: смена меток ноды не выселит уже запущенные
  поды.

> Проверка: команды сверены с `kubectl <cmd> --help` (v1.34.1); taint,
> label, cordon/drain, `create pdb/quota/priorityclass`, сниппеты
> (`--dry-run=server`) и QoS прогнаны на временном kind-кластере;
> не проверено: `kubectl top` (нет metrics-server), descheduler.
