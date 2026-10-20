# Policy Engines: Gatekeeper и Kyverno — шпаргалка

Подробности и объяснения — в
[policy_engines.md](./01_theory/policy_engines.md). ⚠️ — опасная
команда или частая ловушка.

## Что выбрать

| Критерий | OPA Gatekeeper | Kyverno | ValidatingAdmissionPolicy |
| :--- | :--- | :--- | :--- |
| Язык | Rego | YAML-паттерны, CEL | CEL, встроено в apiserver (GA 1.30) |
| Мутации | есть (`Assign`, `AssignMetadata`) | `mutate`, `generate` | нет (MutatingAdmissionPolicy моложе) |
| Порог входа | высокий | низкий | низкий, без отдельного движка |
| Вне Kubernetes | OPA: CI, Envoy, Terraform (conftest) | только Kubernetes | только Kubernetes |
| Отказ движка по умолчанию | `Ignore` (fail-open) | `Fail` (fail-closed) | вебхука нет — нечему падать |

## Gatekeeper

| Задача | Команда |
| :--- | :--- |
| Шаблоны и их статус | `kubectl get constrainttemplates` |
| Все constraints | `kubectl get constraints` |
| Нарушения, найденные аудитом | `kubectl get k8sdisallowedtags no-latest-tag -o jsonpath='{.status.totalViolations}'` |
| Детали нарушений | `kubectl describe k8sdisallowedtags no-latest-tag` → `Violations` |
| Тест политик офлайн | `gator verify ./suite.yaml` |
| Проверить манифесты против шаблонов | `gator test -f ./policies/ -f ./manifests/` |
| Вебхуки и их `failurePolicy` | `kubectl get validatingwebhookconfiguration gatekeeper-validating-webhook-configuration -o yaml` |

| `enforcementAction` в Constraint | Поведение |
| :--- | :--- |
| `deny` (по умолчанию) | отклонить запрос |
| `warn` | пропустить, предупреждение в kubectl |
| `dryrun` | только аудит (`status.violations`) |

```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sDisallowedTags
metadata: {name: no-latest-tag}
spec:
  enforcementAction: dryrun        # сначала аудит, потом deny
  match:
    kinds: [{apiGroups: [""], kinds: ["Pod"]}]
    excludedNamespaces: [kube-system]
```

## Kyverno

| Задача | Команда |
| :--- | :--- |
| Политики кластера / namespace | `kubectl get clusterpolicy`; `kubectl get policy -A` |
| Отчёты о нарушениях (Audit) | `kubectl get policyreport -A`; `kubectl get clusterpolicyreport` |
| Проверить манифест офлайн | `kyverno apply policy.yaml --resource pod.yaml` |
| Юнит-тесты политик (`kyverno-test.yaml`) | `kyverno test ./policies/` |
| Исключение для конкретного ресурса | объект `PolicyException` (`kyverno.io/v2`) |
| Вебхуки Kyverno | `kubectl get validatingwebhookconfiguration,mutatingwebhookconfiguration \| grep kyverno` |

| Поле (Kyverno 1.13+) | Значение |
| :--- | :--- |
| `validate.failureAction` | `Enforce` — блок, `Audit` — только отчёт |
| `spec.validationFailureAction` | устарело — не использовать |
| `match.any` / `match.all` | ИЛИ / И по фильтрам ресурсов |
| `spec.failurePolicy` | `Fail` (по умолчанию) / `Ignore` |
| `spec.background` | `true` — проверять и уже существующие ресурсы |

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata: {name: add-default-limits}
spec:
  rules:
    - name: add-limits
      match:
        any:
          - resources: {kinds: [Pod]}
      mutate:
        patchStrategicMerge:
          spec:
            containers:
              - (name): "*"
                resources:
                  limits:
                    +(memory): 128Mi    # «+()» — только если не задано
```

## Встроенная ValidatingAdmissionPolicy (CEL)

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata: {name: no-latest}
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: [v1]
        operations: [CREATE, UPDATE]
        resources: [pods]
  validations:
    - expression: >-
        object.spec.containers.all(c, !c.image.endsWith(':latest'))
      message: "Тег :latest запрещён"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata: {name: no-latest}
spec:
  policyName: no-latest
  validationActions: [Deny]       # или [Warn, Audit]
```

## failurePolicy вебхука

| Значение | Движок недоступен → | Риск |
| :--- | :--- | :--- |
| `Fail` | запросы под правило отклоняются | кластер частично парализован |
| `Ignore` | запросы проходят без проверки | дыра в политике |

| Параметр вебхука | Значение |
| :--- | :--- |
| `timeoutSeconds` | 1–30, по умолчанию 10 |
| `namespaceSelector` | исключить `kube-system` и namespace движка |
| Реплики движка | ≥3 + PDB — чтобы выбор `Fail`/`Ignore` не всплывал |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| `admission webhook "..." denied the request: ...` | сообщение политики; `kubectl get constraints` / `clusterpolicy` |
| `failed calling webhook ... context deadline exceeded` | поды движка, их Service, `failurePolicy: Fail` |
| Ничего не создаётся после падения Kyverno | вебхуки с `Fail` → поднять Kyverno; в аварию — удалить его webhookconfiguration ⚠️ |
| Политика «не работает» | `failureAction: Audit`/`enforcementAction: dryrun`, не тот `match` |
| Старые ресурсы нарушают, новые нет | admission проверяет только запросы → отчёты аудита |

## Ловушки

- ⚠️ Вебхук без исключения `kube-system` может не дать подняться самому
  движку и CoreDNS после рестарта кластера.
- ⚠️ Kyverno сам пересоздаёт свои вебхуки: ручная правка
  `failurePolicy` откатится — меняйте `spec.failurePolicy` в политике.
- Mutating выполняется до Validating — проверяется уже исправленный
  объект.
- Свежий Kyverno помечает `ClusterPolicy` устаревшим в пользу
  `ValidatingPolicy`/`MutatingPolicy` (`policies.kyverno.io`).

> Проверка: ValidatingAdmissionPolicy и Binding применены и проверены
> отказом пода `:latest` на временном kind-кластере; kubectl-команды
> сверены с `--help` (v1.34.1); не проверено: Gatekeeper, `gator`,
> Kyverno и `kyverno` CLI (движки не ставились).
