# Pod Security — шпаргалка

Подробности и объяснения — в
[01_theory/pod_security.md](./01_theory/pod_security.md).
⚠️ — опасная команда или частая ловушка.

## PSS: уровни

| Уровень | Запрещает / требует | Для кого |
| :--- | :--- | :--- |
| `privileged` | ничего | CNI, CSI, node-агенты |
| `baseline` | `privileged`, `hostNetwork/hostPID/hostIPC`, `hostPath`, `hostPort`, опасные capabilities, unsafe sysctls | старт для большинства приложений |
| `restricted` | baseline + `runAsNonRoot: true`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]` (add только `NET_BIND_SERVICE`), `seccompProfile` `RuntimeDefault`/`Localhost`, ограниченные типы volumes | production-приложения |

## PSA: labels на namespace

| Режим | Что делает | Проверяет |
| :--- | :--- | :--- |
| `enforce` | отклоняет Pod | только Pod'ы ⚠️ |
| `audit` | аннотация в audit log | Pod'ы и workload'ы |
| `warn` | предупреждение в `kubectl` | Pod'ы и workload'ы |

| Задача | Команда |
| :--- | :--- |
| Включить enforce + закрепить версию | `kubectl label --overwrite ns prod pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=v1.30` |
| Мягкое ужесточение | `kubectl label --overwrite ns prod pod-security.kubernetes.io/warn=restricted pod-security.kubernetes.io/audit=restricted` |
| Сухой прогон по запущенным Pod'ам | `kubectl label --dry-run=server --overwrite ns prod pod-security.kubernetes.io/enforce=restricted` |
| Labels всех namespace | `kubectl get ns -L pod-security.kubernetes.io/enforce,pod-security.kubernetes.io/warn` |
| Почему Deployment без Pod'ов | `kubectl describe rs -n prod` → `violates PodSecurity` |

Типовая схема: `enforce=baseline` (версия закреплена) +
`warn/audit=restricted` (`latest`).

## securityContext под restricted

```yaml
spec:
  automountServiceAccountToken: false
  securityContext:                    # уровень Pod
    runAsNonRoot: true
    runAsUser: 10001
    runAsGroup: 10001
    fsGroup: 10001
    fsGroupChangePolicy: OnRootMismatch
    seccompProfile: {type: RuntimeDefault}
  containers:
    - name: app
      securityContext:                # уровень контейнера (перекрывает Pod)
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities: {drop: ["ALL"]}
      volumeMounts: [{name: tmp, mountPath: /tmp}]
  volumes:
    - {name: tmp, emptyDir: {sizeLimit: 100Mi}}
```

| Поле | Зачем / типичное значение |
| :--- | :--- |
| `runAsNonRoot: true` | kubelet откажется запускать, если UID 0 (`CreateContainerConfigError`) |
| `runAsUser` | числовой UID; с `USER appuser` (имя) `runAsNonRoot` не проверить ⚠️ |
| `fsGroup` | GID для томов; chown на старте — `OnRootMismatch` ускоряет |
| `readOnlyRootFilesystem` | запись только в `emptyDir` (`/tmp`, кэш) |
| `capabilities.add: [NET_BIND_SERVICE]` | порты < 1024 без root |
| `seccompProfile.type: Localhost` | `localhostProfile: profiles/app.json` из `/var/lib/kubelet/seccomp/` |
| `sysctls` | без флагов kubelet — только safe (`net.ipv4.ip_local_port_range`, `net.ipv4.tcp_syncookies`...) |

## Capabilities и seccomp на ноде

| Задача | Команда |
| :--- | :--- |
| Capabilities процесса | `grep Cap /proc/<pid>/status` → `capsh --decode=<CapEff>` |
| Из контейнера | `kubectl exec pod -- grep Cap /proc/1/status` |
| Seccomp-режим процесса | `grep Seccomp /proc/<pid>/status` (`2` = filter) |
| Кто нарушает seccomp (режим log) | `journalctl -k \| grep -i seccomp` / `ausearch -m SECCOMP` |

| Capability | Комментарий |
| :--- | :--- |
| `NET_BIND_SERVICE` | порты < 1024 — единственная разрешённая в restricted |
| `NET_RAW` | есть в Docker по умолчанию, нужна для `ping`; ARP/DNS spoofing ⚠️ |
| `SYS_PTRACE` | отладчики, профилировщики — не в prod |
| `SYS_ADMIN` | почти root ⚠️ |

## Policy engines

| Нужно | Чем |
| :--- | :--- |
| Стандартные уровни, без своих правил | PSA (встроен) |
| Свои правила YAML-паттернами, мутация, генерация, verifyImages | Kyverno (`validate.failureAction: Enforce\|Audit`) |
| Rego-политики, общий язык с OPA вне k8s | Gatekeeper (`ConstraintTemplate` + Constraint) |

| Задача | Команда |
| :--- | :--- |
| Отчёты Kyverno (Audit) | `kubectl get policyreport -A` |
| Нарушения Gatekeeper | `kubectl get <constraint-kind> -o yaml` (`status.violations`) |
| Линт манифеста локально | `kube-score score d.yaml` / `kubesec scan d.yaml` / `checkov -f d.yaml --framework kubernetes` |

## Ловушки

| ⚠️ | Суть |
| :--- | :--- |
| PSA не мутирует | `runAsNonRoot`, seccomp и т.п. прописывать в манифестах/чартах |
| `enforce` на Deployment | Deployment создаётся, Pod'ы — нет; смотреть ReplicaSet |
| `enforce-version: latest` | апгрейд кластера может ужесточить правила |
| Смена labels | уже запущенные Pod'ы не удаляются |
| Exemption по `usernames` | Pod'ы от контроллеров всё равно проверяются |
| PSP | удалена в 1.25; замена — PSA + policy engine |
| Managed-кластеры | флаги apiserver недоступны — только labels |

> Проверка: YAML — `yamllint` и `kubeconform`; `kubectl label/get -L`
> сверены с `--help` kubectl v1.34.1; не проверено: PSA и
> Kyverno/Gatekeeper на живом кластере (kind не поднимался).
