# Pod Security

## Pod Security Standards (PSS) и Pod Security Admission (PSA)

Это каноническое место про PSS/PSA в базе; разделы
[3_containers/05_security](../../../3_containers/05_security/) и
[4_kubernetes/06_security](../../../4_kubernetes/06_security/) дают
только краткое описание и ссылаются сюда.

Два термина, которые часто путают:

1. **Pod Security Standards (PSS)** — документ: три уровня требований к
   полям Pod (что запрещено на каждом уровне).
2. **Pod Security Admission (PSA)** — встроенный admission controller
   `PodSecurity` в kube-apiserver, который проверяет Pod'ы по этим
   уровням. Включён по умолчанию с 1.23 (beta), GA — в 1.25.

PSA только **проверяет** (validating), ничего не исправляет: если Pod
нарушает уровень, он будет отклонён или помечен предупреждением, но
`runAsNonRoot` за вас никто не подставит.

### Уровни

| Уровень | Что ограничивает | Когда использовать |
|---------|------------------|--------------------|
| **privileged** | Ничего | Системные компоненты (CNI, CSI, node agents) |
| **baseline** | Запрещает известные эскалации: privileged, hostNetwork/hostPID/hostIPC, hostPath, hostPort, опасные capabilities | Большинство приложений, точка старта |
| **restricted** | baseline + обязательные runAsNonRoot, allowPrivilegeEscalation: false, drop ALL capabilities (можно вернуть только NET_BIND_SERVICE), seccompProfile RuntimeDefault/Localhost, ограниченный набор типов volumes | Production-приложения |

Pod, который проходит restricted, выглядит как пример из раздела
«securityContext» ниже.

### Режимы: enforce, audit, warn

На namespace можно повесить три независимых режима, каждый со своим
уровнем:

1. `enforce` — Pod, нарушающий уровень, **отклоняется** apiserver'ом.
2. `audit` — Pod создаётся, нарушение пишется аннотацией в audit log
   (если audit log включён, см. [08_runtime_security](../../08_runtime_security/)).
3. `warn` — Pod создаётся, `kubectl` показывает предупреждение.

Важная деталь: `enforce` проверяет **только Pod'ы**. Deployment с
нарушениями создастся, а его ReplicaSet молча не сможет создать Pod'ы
(ошибка видна в `kubectl describe rs`). `audit` и `warn` проверяют и
workload-ресурсы (Deployment, Job...) — поэтому их полезно включать
вместе с `enforce`.

### Labels на namespace и фиксация версии

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/enforce-version: v1.30

    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest

    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: latest
```

`<mode>-version` фиксирует, по правилам какой версии Kubernetes
проверять уровень. `latest` — правила текущей версии apiserver: при
апгрейде кластера требования могут ужесточиться, и Pod'ы, которые
проходили вчера, перестанут создаваться. Поэтому для `enforce` в
production версию закрепляют (`v1.30`) и поднимают осознанно, а
`warn`/`audit` оставляют на `latest`, чтобы заранее видеть, что
сломается. Типичная схема выше: enforce baseline + warn/audit
restricted — постепенное ужесточение без поломок.

```bash
# Применить labels к существующему namespace
kubectl label --overwrite ns production \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.30

# Сухой прогон: какие из уже запущенных Pod'ов нарушат уровень
kubectl label --dry-run=server --overwrite ns production \
  pod-security.kubernetes.io/enforce=restricted
# Warning: existing pods in namespace "production" violate the new
# PodSecurity enforce level "restricted:latest"
# Warning: web-7d4b9c-x2x9k: allowPrivilegeEscalation != false, ...
```

Уже запущенные Pod'ы при смене labels **не удаляются** — проверка
срабатывает при создании/обновлении Pod'а.

### Значения по умолчанию и исключения (exemptions)

Namespace без labels получает уровни по умолчанию из конфигурации
admission-плагина (по умолчанию — `privileged`, то есть без проверок).
Кластерные defaults и исключения задаются файлом, который передаётся
kube-apiserver через `--admission-control-config-file`:

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
  - name: PodSecurity
    configuration:
      apiVersion: pod-security.admission.config.k8s.io/v1
      kind: PodSecurityConfiguration
      defaults:                # для namespace без labels
        enforce: baseline
        enforce-version: latest
        audit: restricted
        audit-version: latest
        warn: restricted
        warn-version: latest
      exemptions:
        usernames: []          # запросы от этих пользователей не проверяются
        runtimeClasses: []     # Pod'ы с этим runtimeClassName
        namespaces: [kube-system]
```

Exemptions — полный обход проверки, поэтому их держат минимальными.
Исключение по `usernames` действует только на запросы этого
пользователя напрямую: Pod'ы, которые создаёт контроллер (ReplicaSet
от Deployment), всё равно проверяются. Чаще вместо exemptions просто
ставят на системный namespace `enforce: privileged`. В managed-кластерах
(EKS/GKE/AKS) флаги apiserver недоступны — там работают только labels.

### Миграция с PodSecurityPolicy

PodSecurityPolicy (PSP) объявлена устаревшей в 1.21 и **удалена в
1.25**. Отличия, которые важны при миграции:

1. PSP умела **мутировать** Pod (подставлять `runAsUser`, seccomp,
   `allowPrivilegeEscalation: false`), PSA — нет. Эти значения нужно
   явно прописать в манифестах/Helm-чартах или перенести мутацию в
   Kyverno/Gatekeeper.
2. PSP назначалась через RBAC (`use` на политику) на ServiceAccount,
   PSA — через labels на namespace. Тонкие per-SA различия внутри одного
   namespace в PSA невозможны: такие workloads разносят по namespace или
   описывают политикой Kyverno/Gatekeeper (раздел ниже).
3. PSA работает фиксированными уровнями, кастомных полей нет. Если
   нужны свои правила (разрешённые registry, обязательные labels) — это
   задача policy engine.

Порядок миграции:

1. Для каждого namespace выбрать целевой уровень; проверить его
   `kubectl label --dry-run=server` (см. выше).
2. Включить `warn` и `audit` с целевым уровнем, исправить манифесты по
   предупреждениям и audit log.
3. Включить `enforce` (с закреплённой версией).
4. Только после этого удалить PSP-объекты и выключить плагин
   `PodSecurityPolicy` (обязательно до апгрейда на 1.25).

## securityContext — полный набор для production

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      # Pod-level securityContext
      securityContext:
        runAsNonRoot: true           # запрет запуска как root
        runAsUser: 1000              # UID пользователя
        runAsGroup: 1000             # GID группы
        fsGroup: 1000                # GID для mounted volumes
        fsGroupChangePolicy: OnRootMismatch  # не chown если уже правильный GID
        supplementalGroups: [2000]   # дополнительные группы
        
        seccompProfile:
          type: RuntimeDefault       # стандартный seccomp профиль (ядро ограничивает syscalls)
        
        sysctls:                     # без флагов kubelet — только safe sysctls
          - name: net.ipv4.ip_local_port_range  # (net.core.somaxconn — unsafe:
            value: "1024 65000"                 # нужен --allowed-unsafe-sysctls)

      containers:
        - name: app
          # Container-level securityContext (переопределяет Pod-level)
          securityContext:
            allowPrivilegeEscalation: false  # нельзя получить больше прав чем у процесса
            readOnlyRootFilesystem: true     # ФС контейнера read-only
            
            capabilities:
              drop: ["ALL"]                  # убрать все Linux capabilities
              add: ["NET_BIND_SERVICE"]      # добавить только нужные
            
            runAsNonRoot: true
            runAsUser: 1000
            
            seccompProfile:
              type: Localhost
              localhostProfile: "profiles/my-app.json"  # кастомный профиль

          volumeMounts:
            - name: tmp
              mountPath: /tmp          # tmpfs для временных файлов
            - name: cache
              mountPath: /app/cache

      volumes:
        - name: tmp
          emptyDir: {}
        - name: cache
          emptyDir:
            sizeLimit: 100Mi
```

## Linux Capabilities — что разрешать

```bash
# Посмотреть capabilities процесса
cat /proc/1/status | grep Cap
capsh --decode=00000000a80425fb

# Capabilities по умолчанию в Docker контейнере:
# CAP_CHOWN, CAP_DAC_OVERRIDE, CAP_FOWNER, CAP_FSETID,
# CAP_KILL, CAP_NET_BIND_SERVICE, CAP_SETGID, CAP_SETUID,
# CAP_NET_RAW, CAP_SYS_CHROOT, CAP_MKNOD, CAP_AUDIT_WRITE,
# CAP_SETFCAP, CAP_SETPCAP

# Принцип: drop ALL, добавить только нужные
# Типичные нужные:
# NET_BIND_SERVICE  — слушать порты < 1024 (nginx :80)
# SYS_PTRACE        — профилировщики, отладчики (НЕ в prod)
# SYS_ADMIN         — опасно, почти = root
```

## Seccomp профили

```bash
# RuntimeDefault — профиль container runtime: запрещает несколько десятков
# опасных syscalls (mount, kexec_load, bpf и т.п.), остальные разрешены

# Создать кастомный профиль для конкретного приложения
# Сначала запустить с seccomp=log чтобы видеть что используется
# Потом создать разрешающий профиль только для нужных syscalls

# /var/lib/kubelet/seccomp/profiles/nginx.json
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": ["SCMP_ARCH_X86_64"],
  "syscalls": [
    {
      "names": ["read", "write", "open", "close", "stat", "accept", "connect", "epoll_wait"],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
```

## Policy engines: Kyverno и OPA Gatekeeper — admission control

Нужны, когда фиксированных уровней PSS мало: свои правила, мутация,
разные требования внутри namespace. Kyverno с 1.13 задаёт режим на
уровне правила (`validate.failureAction: Enforce | Audit`); старое поле
`spec.validationFailureAction` устарело.

```yaml
# Kyverno policy: запретить запуск как root
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-non-root
spec:
  background: true
  rules:
    - name: check-runAsNonRoot
      match:
        any:
          - resources:
              kinds: [Pod]
      validate:
        failureAction: Enforce
        message: "Containers must run as non-root user"
        pattern:
          spec:
            containers:
              - securityContext:
                  runAsNonRoot: true

---
# OPA Gatekeeper ConstraintTemplate
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8snoroot
spec:
  crd:
    spec:
      names:
        kind: K8sNoRoot
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8snoroot
        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.securityContext.runAsNonRoot
          msg := sprintf("Container '%v' must set runAsNonRoot=true", [container.name])
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sNoRoot
metadata:
  name: no-root-containers
spec:
  match:
    # rego выше читает spec.containers — это путь Pod'а, поэтому match
    # по Pod (у Deployment контейнеры в spec.template.spec.containers)
    kinds: [{apiGroups: [""], kinds: ["Pod"]}]
    namespaces: [production, staging]
```

## Проверка конфигурации

```bash
# kube-score — проверить manifest на best practices
kube-score score deployment.yaml

# kubesec — security score
kubesec scan deployment.yaml

# Checkov — IaC сканер поддерживает k8s manifests
checkov -f deployment.yaml --framework kubernetes

# kubectl-neat — убрать шум из describe
kubectl get pod mypod -o yaml | kubectl neat
```
