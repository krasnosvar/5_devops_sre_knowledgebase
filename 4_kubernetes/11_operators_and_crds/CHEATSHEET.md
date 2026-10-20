# CRD и Operators — шпаргалка

Подробности и объяснения — в
[operators_and_crds.md](./01_theory/operators_and_crds.md).
⚠️ — опасная команда или частая ловушка.

## Команды

| Задача | Команда |
| :--- | :--- |
| Все CRD в кластере | `kubectl get crd` |
| CRD одной группы | `kubectl get crd \| grep example.com` |
| Версии, scope, схема | `kubectl get crd websites.example.com -o yaml` |
| Дождаться регистрации типа | `kubectl wait --for=condition=Established crd/websites.example.com --timeout=60s` |
| Ресурсы, добавленные CRD | `kubectl api-resources --api-group=example.com` |
| Поля CR из схемы | `kubectl explain website.spec` |
| Объекты CR | `kubectl get websites -A` (или по полному имени `websites.example.com`) |
| Конкретная версия API | `kubectl get websites.v1.example.com` |
| Кто управляет CR (контроллер жив?) | `kubectl get pods -A -l <label оператора>`, `kubectl logs deploy/<operator> -n <ns>` |
| Статус и события CR | `kubectl describe website mysite` (`status.conditions`, `Events`) |
| Удалить CRD ⚠️ | `kubectl delete crd websites.example.com` — удаляет **все** CR этого типа |
| Снять зависший finalizer ⚠️ | `kubectl patch website mysite --type=merge -p '{"metadata":{"finalizers":null}}'` |

## Минимальная CRD

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: websites.example.com          # <plural>.<group>
spec:
  group: example.com
  names: {kind: Website, plural: websites, singular: website, shortNames: [ws]}
  scope: Namespaced
  versions:
    - name: v1
      served: true
      storage: true
      subresources: {status: {}}
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                domain: {type: string}
                replicas: {type: integer, minimum: 1}
```

| Поле | Смысл |
| :--- | :--- |
| `metadata.name` | строго `<plural>.<group>` |
| `scope` | `Namespaced` или `Cluster` |
| `served: true` | версия доступна через REST |
| `storage: true` | в этой версии объект лежит в etcd; ровно одна версия |
| `subresources.status` | `status` пишется отдельно (`/status`), `spec` — пользователем |
| `additionalPrinterColumns` | колонки в `kubectl get` |
| `conversion.strategy: Webhook` | конвертация между версиями своим webhook |

## Operator: reconcile loop

| Шаг | Что делает |
| :--- | :--- |
| Watch | Informer: List + Watch, локальный кэш объектов |
| Reconcile | желаемое (`spec` CR) vs фактическое (кластер / внешняя система) |
| Act | создать / изменить / удалить дочерние ресурсы |
| Status | записать `status.conditions`, `observedGeneration` |
| Requeue | повторить при ошибке или по таймеру |

| Правило | Почему |
| :--- | :--- |
| Reconcile идемпотентен | после рестарта оператор заново сверяет всё по List |
| Состояние — в кластере, не в памяти | память процесса теряется при OOM/деплое |
| `ownerReferences` на дочерних объектах | GC удалит их вместе с CR |
| Finalizer для внешних ресурсов | успеть удалить облачный ресурс до удаления CR |

## Когда что

| Задача | Решение |
| :--- | :--- |
| Только хранить конфиг | ConfigMap |
| Свой тип с валидацией, без логики | CRD (без оператора — «мёртвая запись») |
| Тип + автоматизация жизненного цикла | CRD + Operator |
| Написать оператор на Go | Kubebuilder / Operator SDK (`controller-runtime`) |

| Готовый оператор | Его CR |
| :--- | :--- |
| cert-manager | `Certificate`, `Issuer`, `ClusterIssuer` |
| External Secrets Operator | `ExternalSecret`, `SecretStore` |
| Karpenter | `NodePool`, `NodeClaim` |
| Prometheus Operator | `ServiceMonitor`, `PodMonitor`, `PrometheusRule` |
| Argo CD | `Application`, `ApplicationSet`, `AppProject` |

## Симптом → куда смотреть

| Симптом | Причина / проверка |
| :--- | :--- |
| CR создан, ничего не происходит | оператор не запущен или не смотрит этот namespace |
| `no matches for kind "Website"` | CRD не установлена / не `Established` / не та версия |
| CR завис в `Terminating` | finalizer, оператор удалён или падает |
| `strict decoding error: unknown field` | поле не описано в `openAPIV3Schema` |
| CR не обновляется, `status` старый | `observedGeneration` < `generation`: смотреть логи оператора |

> Проверка: команды сверены с `kubectl --help` (v1.34.1), CRD —
> `yamllint`; не проверено: применение CRD и поведение finalizer (нужен
> кластер).
