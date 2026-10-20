# Kubernetes RBAC — шпаргалка

Подробности и объяснения — в
[01_theory/k8s_rbac_deep.md](./01_theory/k8s_rbac_deep.md).
⚠️ — опасная команда или частая ловушка.

## Модель: кто × что × где

| Объект | Scope | Связывается через | Итоговые права |
| :--- | :--- | :--- | :--- |
| `Role` | namespace | `RoleBinding` | в этом namespace |
| `ClusterRole` | кластер | `ClusterRoleBinding` | во всём кластере ⚠️ |
| `ClusterRole` | кластер | `RoleBinding` | только в namespace binding'а |
| Subject `User` / `Group` | — | CN / O сертификата, OIDC claims | объектов User в API нет |
| Subject `ServiceAccount` | namespace | `system:serviceaccount:<ns>:<sa>` | группа `system:serviceaccounts:<ns>` |

| Встроенная ClusterRole | Что даёт |
| :--- | :--- |
| `cluster-admin` | всё, везде ⚠️ |
| `admin` | всё в namespace, включая Role/RoleBinding; без ResourceQuota и самого Namespace |
| `edit` | чтение/запись большинства объектов (включая Secrets), без RBAC |
| `view` | только чтение; Secrets не видит |

## Проверить права

| Задача | Команда |
| :--- | :--- |
| Кто я для apiserver | `kubectl auth whoami` |
| Могу ли я | `kubectl auth can-i create deployments -n prod` |
| Может ли SA | `kubectl auth can-i get secrets -n prod --as=system:serviceaccount:prod:myapp` |
| Может ли пользователь из группы | `kubectl auth can-i delete pods --as=alice --as-group=developers` |
| Все права субъекта в namespace | `kubectl auth can-i --list --as=system:serviceaccount:prod:myapp -n prod` |
| Подресурс | `kubectl auth can-i get pods --subresource=log` / `create pods/exec` |
| Только код возврата (для скриптов) | `kubectl auth can-i get secrets -q` |
| Кто может действие (krew-плагин `who-can`) | `kubectl who-can delete secrets -n prod` |
| Матрица прав (krew-плагин rakkess) | `kubectl access-matrix --sa prod:myapp -n prod` |

⚠️ `--as` требует права `impersonate` у того, кто проверяет.

## Выдать права

| Задача | Команда |
| :--- | :--- |
| Role на конкретные объекты | `kubectl create role app-cfg -n prod --verb=get,list,watch --resource=configmaps --resource-name=myapp-config` |
| Готовая ClusterRole в одном namespace | `kubectl create rolebinding alice-view --clusterrole=view --user=alice -n prod` |
| Привязать SA | `kubectl create rolebinding app --role=app-cfg --serviceaccount=prod:myapp -n prod` |
| Cluster-wide ⚠️ | `kubectl create clusterrolebinding x --clusterrole=cluster-admin --user=alice` |
| Сгенерировать YAML, не применяя | `... --dry-run=client -o yaml` |
| Краткоживущий токен SA | `kubectl create token myapp -n prod --duration=10m` |
| Привести RBAC к файлу (без удаления лишних прав) | `kubectl auth reconcile -f rbac.yaml` |

```yaml
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get"]
    resourceNames: ["myapp-db", "myapp-tls"]  # только эти объекты
  - apiGroups: ["apps"]
    resources: ["deployments", "deployments/scale"]
    verbs: ["get", "patch"]
```

## Аудит

| Задача | Команда |
| :--- | :--- |
| Все привязки к `cluster-admin` | `kubectl get clusterrolebindings -o json \| jq -r '.items[] \| select(.roleRef.name=="cluster-admin") \| .metadata.name'` |
| Binding'и, ссылающиеся на admin/edit | `kubectl get rolebindings,clusterrolebindings -A -o json \| jq '.items[] \| select(.roleRef.name \| test("admin\|edit"))'` |
| Правила роли | `kubectl describe clusterrole edit` |
| Pod'ы с автомонтированием токена | `kubectl get pods -A -o json \| jq -r '.items[] \| select(.spec.automountServiceAccountToken != false) \| .metadata.namespace+"/"+.metadata.name'` |

## Пользователь по сертификату

| Шаг | Команда |
| :--- | :--- |
| Ключ + CSR (CN=user, O=group) | `openssl req -new -newkey rsa:2048 -nodes -keyout alice.key -out alice.csr -subj "/CN=alice/O=developers"` |
| CSR в кластер | `CertificateSigningRequest`, `signerName: kubernetes.io/kube-apiserver-client`, `usages: [client auth]` |
| Одобрить / забрать | `kubectl certificate approve alice`<br>`kubectl get csr alice -o jsonpath='{.status.certificate}' \| base64 -d > alice.crt` |
| В kubeconfig | `kubectl config set-credentials alice --client-certificate=alice.crt --client-key=alice.key --embed-certs=true` |
| Кто в сертификате | `openssl x509 -in alice.crt -noout -subject -enddate` |

## Ловушки

| ⚠️ | Суть |
| :--- | :--- |
| `resourceNames` + `list`/`watch` | сработает, только если клиент шлёт `fieldSelector=metadata.name=<имя>`; `create` и `deletecollection` по имени не ограничить |
| `list` на secrets | отдаёт содержимое всех секретов — то же, что `get *` |
| `create pods` в namespace | даёт доступ ко всем Secrets/SA этого namespace (смонтировать в свой Pod) |
| `escalate` / `bind` / `impersonate` | обход RBAC: можно выдать себе любые права |
| Отзыв сертификата | невозможен — только короткий срок (`expirationSeconds`) или смена CA |
| `automountServiceAccountToken` | `true` по умолчанию; приложениям без API ставить `false` |
| Один SA на несколько сервисов | компрометация одного = всех |
| `apiGroups/resources/verbs: ["*"]` | wildcard покрывает и будущие ресурсы (CRD) |

> Проверка: флаги `kubectl auth can-i/whoami/reconcile`, `create role/
> rolebinding/token` сверены с `--help` kubectl v1.34.1 (без кластера);
> не проверено: плагины `who-can`, `access-matrix` (нет локально),
> jq-фильтры на живом кластере.
