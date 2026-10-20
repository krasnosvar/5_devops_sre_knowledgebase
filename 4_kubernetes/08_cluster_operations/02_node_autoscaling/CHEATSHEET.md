# Автоскейлинг нод — шпаргалка

Подробности и объяснения — в
[node_autoscaling.md](./01_theory/node_autoscaling.md).
⚠️ — опасная команда или частая ловушка. Без лабы: нужен облачный API.

## Cluster Autoscaler vs Karpenter

| | Cluster Autoscaler | Karpenter |
| :--- | :--- | :--- |
| Триггер | `Pending` поды (`FailedScheduling`) | `Pending` поды |
| Как добавляет ноду | меняет `Desired Capacity` у ASG / NodeGroup | сам вызывает API облака (`RunInstances` в EC2) |
| Типы инстансов | заранее заданы в NodeGroup | подбирает под `requests` из разрешённых `requirements` |
| Скорость | минуты | ~10–40 с до ноды |
| Новый тип (GPU) без группы | под висит `Pending` | создаст, если разрешено в `NodePool` |
| Уплотнение | scale-down пустых/недогруженных нод, консервативно | Consolidation: замена и уплотнение нод |
| Конфигурация | флаги деплоймента CA + NodeGroups | CRD `NodePool` + `EC2NodeClass` (AWS) |

| Ситуация | Выбор |
| :--- | :--- |
| AWS EKS, разнородная нагрузка, spot | Karpenter |
| Облако без провайдера Karpenter, managed NodeGroups | Cluster Autoscaler |
| Нужна только реакция на нехватку `requests` | любой: оба не смотрят на реальную загрузку CPU |

⚠️ Оба реагируют только на `Pending`. Под без `requests` не вызывает
масштабирования, сколько бы CPU он ни ел.

## Karpenter v1: минимальный NodePool

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata: {name: default}
spec:
  template:
    spec:
      requirements:
        - {key: karpenter.sh/capacity-type, operator: In, values: ["spot", "on-demand"]}
        - {key: kubernetes.io/arch, operator: In, values: ["amd64"]}
      nodeClassRef: {group: karpenter.k8s.aws, kind: EC2NodeClass, name: default}
  limits: {cpu: 1000}
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized   # или WhenEmpty
    consolidateAfter: 1m
```

| Поле / объект | Смысл |
| :--- | :--- |
| `NodePool` | требования к нодам, лимиты, политика disruption |
| `EC2NodeClass` | AMI, подсети, security groups, роль (AWS) |
| `NodeClaim` | заявка на конкретную ноду, создаёт Karpenter |
| `limits.cpu` | потолок суммарного CPU нод пула |
| `consolidationPolicy` (v1) | `WhenEmptyOrUnderutilized` (бывш. `WhenUnderutilized`) / `WhenEmpty` |
| `karpenter.sh/do-not-disrupt: "true"` | аннотация пода: не трогать его ноду при consolidation |

## Команды

| Задача | Команда |
| :--- | :--- |
| Почему под не размещён | `kubectl get events -A --field-selector reason=FailedScheduling` |
| Пулы и заявки Karpenter | `kubectl get nodepools,nodeclaims` |
| Почему Karpenter не создал ноду | `kubectl describe nodeclaim <name>`, логи `kubectl logs -n kube-system deploy/karpenter` (namespace — где установлен) |
| Метки нод Karpenter | `kubectl get nodes -L karpenter.sh/nodepool,karpenter.sh/capacity-type,node.kubernetes.io/instance-type` |
| Статус CA | `kubectl -n kube-system get configmap cluster-autoscaler-status -o yaml` |
| Решения CA | `kubectl -n kube-system logs deploy/cluster-autoscaler \| grep -iE 'scale.?up\|scale.?down'` |
| Запретить CA удалять ноду | аннотация ноды `cluster-autoscaler.kubernetes.io/scale-down-disabled=true` |
| Запретить CA выселять под | аннотация пода `cluster-autoscaler.kubernetes.io/safe-to-evict: "false"` |

## Симптом → куда смотреть

| Симптом | Причина / проверка |
| :--- | :--- |
| Под `Pending`, ноды не добавляются (CA) | нет NodeGroup, подходящей по `nodeSelector`/taints/ресурсам; достигнут `max` ASG |
| Под `Pending`, Karpenter молчит | `requirements` NodePool не пересекаются с требованиями пода; упёрлись в `limits` |
| Ноды не удаляются | PDB с `ALLOWED DISRUPTIONS: 0`, `do-not-disrupt`/`safe-to-evict: false`, локальные данные |
| Поды постоянно переезжают | агрессивная consolidation: увеличить `consolidateAfter`, поставить PDB |
| Счёт за облако растёт, ноды полупустые | завышенные `requests`; см. VPA в [10_pod_autoscaling](../../10_pod_autoscaling/CHEATSHEET.md) |

> Проверка: YAML NodePool проверен `yamllint`; не проверено: команды и
> CRD Karpenter/CA (нужен облачный кластер), имена аннотаций — по
> документации проектов.
