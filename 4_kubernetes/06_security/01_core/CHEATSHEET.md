# Безопасность Kubernetes: основы — шпаргалка

Подробности и объяснения — в [security.md](./01_theory/security.md).
Глубже — в [10_devsecops](../../../10_devsecops/). ⚠️ — опасная команда
или частая ловушка.

## RBAC: что с чем связывать

| Нужно | Объекты |
| :--- | :--- |
| Права в одном namespace | `Role` + `RoleBinding` |
| Типовой набор прав в нескольких namespace | `ClusterRole` + `RoleBinding` в каждом (права только там) |
| Кластерные ресурсы (nodes, PV, CRD, namespaces) | `ClusterRole` + `ClusterRoleBinding` |
| Права на всё во всех namespace ⚠️ | `ClusterRoleBinding` — выдавать редко |

| Встроенная ClusterRole | Что даёт |
| :--- | :--- |
| `view` | чтение почти всего, кроме Secrets |
| `edit` | изменение workload и Secrets, без RBAC |
| `admin` | всё в namespace, включая Role/RoleBinding |
| `cluster-admin` ⚠️ | всё везде |

| Задача | Команда |
| :--- | :--- |
| Создать Role | `kubectl create role pod-reader --verb=get,list,watch --resource=pods -n dev` |
| Привязать к пользователю/группе | `kubectl create rolebinding vasya-admin --clusterrole=admin --user=vasya -n dev` |
| Привязать к ServiceAccount | `kubectl create rolebinding app-read --role=pod-reader --serviceaccount=dev:app -n dev` |
| Могу ли я | `kubectl auth can-i delete pods -n prod` |
| Может ли другой (impersonation) | `kubectl auth can-i list secrets -n dev --as=system:serviceaccount:dev:app` |
| Все свои права в namespace | `kubectl auth can-i --list -n dev` |
| Кто я (user, groups) | `kubectl auth whoami` |
| Кто ссылается на ClusterRole | `kubectl get rolebindings,clusterrolebindings -A -o wide \| grep cluster-admin` |
| Правила роли | `kubectl describe clusterrole edit` |
| Применить RBAC-манифест с дополнением правил | `kubectl auth reconcile -f rbac.yaml` |

## ServiceAccount и токены

| Задача | Команда / поле |
| :--- | :--- |
| Создать SA | `kubectl create serviceaccount app -n dev` |
| Короткоживущий токен для отладки | `kubectl create token app -n dev --duration=10m` |
| Не монтировать токен | `automountServiceAccountToken: false` (в SA или поде) |
| Путь токена в поде | `/var/run/secrets/kubernetes.io/serviceaccount/token` |
| Токен по умолчанию | projected, bound к поду, ~1 ч, kubelet ротирует |
| Имя SA в RBAC | `system:serviceaccount:<ns>:<name>` |

## SecurityContext (restricted-совместимый)

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    fsGroup: 10001
    seccompProfile: {type: RuntimeDefault}
  containers:
    - name: app
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities: {drop: [ALL]}
```

| Поле | Защищает от |
| :--- | :--- |
| `runAsNonRoot: true` | запуска от UID 0 (под не стартует) |
| `allowPrivilegeEscalation: false` | повышения через SUID (`no_new_privs`) |
| `capabilities.drop: [ALL]` | `NET_RAW`, `SYS_ADMIN` и прочих capabilities |
| `readOnlyRootFilesystem: true` | записи в корень ФС (пишут в `emptyDir`) |
| `seccompProfile: RuntimeDefault` | опасных сисколлов |

## Pod Security Admission

| Задача | Команда |
| :--- | :--- |
| Включить enforce restricted | `kubectl label ns app pod-security.kubernetes.io/enforce=restricted` |
| Сначала только предупреждать | `kubectl label ns app pod-security.kubernetes.io/warn=restricted pod-security.kubernetes.io/audit=restricted` |
| Что сломается (без изменений) | `kubectl label --dry-run=server --overwrite ns app pod-security.kubernetes.io/enforce=restricted` |

| Профиль | Суть |
| :--- | :--- |
| `privileged` | без ограничений |
| `baseline` | нет `privileged`, `hostNetwork`/`hostPID`, `hostPath` |
| `restricted` | + non-root, drop ALL, `allowPrivilegeEscalation: false`, seccomp |

## Secrets, аудит, runtime

| Задача | Команда / решение |
| :--- | :--- |
| Секрет из литерала | `kubectl create secret generic db --from-literal=password=... -n app` |
| Прочитать значение ⚠️ base64 ≠ шифрование | `kubectl get secret db -o jsonpath='{.data.password}' \| base64 -d` |
| Шифрование Secrets в etcd | `--encryption-provider-config` у kube-apiserver (KMS v2 / aescbc) |
| Секреты из Vault / AWS SM | External Secrets Operator: `ExternalSecret` → Secret |
| Секреты в Git | SOPS / SealedSecrets (зашифрованы в репо) |
| Скан образов на CVE | `trivy image nginx:1.27-alpine` |
| Скан манифестов на мисконфиги | `trivy config ./manifests` |
| Детект в рантайме | Falco (драйвер `modern_ebpf`) — алерт, не блокировка |
| Аудит API | `--audit-policy-file`, `--audit-log-path` у kube-apiserver |

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages: [RequestReceived]
rules:
  - level: Metadata             # Secrets — без тела запроса/ответа
    resources: [{group: "", resources: [secrets, configmaps]}]
  - level: RequestResponse
    resources: [{group: "rbac.authorization.k8s.io"}]
  - level: Metadata             # всё остальное
```

| Уровень аудита | Пишет |
| :--- | :--- |
| `None` | ничего |
| `Metadata` | кто, что, когда — без тел |
| `Request` | + тело запроса |
| `RequestResponse` | + тело ответа ⚠️ для Secrets — утечка |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| `Forbidden: User "x" cannot list resource "pods"` | `auth can-i --as=x`, RoleBinding в нужном namespace |
| Под отклонён `violates PodSecurity "restricted:latest"` | список нарушений в ошибке → securityContext |
| Под с `runAsNonRoot` не стартует: `image will run as root` | `USER` в Dockerfile или `runAsUser` |
| App не может писать файлы | `readOnlyRootFilesystem` → `emptyDir` на путь записи |
| Под ходит в API с правами, которых не ждали | SA пода, `automountServiceAccountToken`, биндинги на `default` SA |
| NetworkPolicy «есть», а egress открыт | нет `Egress` в `policyTypes` |

## Ловушки

- ⚠️ Группа `system:masters` в сертификате обходит RBAC целиком — её не
  отозвать через RBAC.
- ⚠️ `hostPath: /` или `privileged: true` = root на ноде.
- В Kubernetes нет объектов User/Group — их даёт OIDC или сертификат.
- RBAC только разрешает: deny-правил нет, отказ — отсутствие разрешения.

> Проверка: kubectl-команды сверены с `--help` (v1.34.1); RBAC,
> `auth can-i --as`/`--list`, `create token`, PSA-метки (включая
> `--dry-run=server`) и securityContext-сниппет прогнаны на временном
> kind-кластере; не проверено: audit-policy (флаги apiserver), ESO,
> SOPS, Falco, trivy.
