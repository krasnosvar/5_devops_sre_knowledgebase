# Pod Security

## Pod Security Standards (PSS)

Три встроенных уровня политик (k8s 1.25+, заменили PodSecurityPolicy):

| Уровень | Описание | Когда использовать |
|---------|----------|-------------------|
| **privileged** | Без ограничений | Системные компоненты (node agents, CNI) |
| **baseline** | Минимальные запреты | Большинство приложений |
| **restricted** | Максимальная безопасность | Production apps, финансы, медицина |

```yaml
# Включить PSS через labels на namespace
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    # enforce: Pod не создастся если нарушает политику
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    
    # warn: создастся, но будет предупреждение в UI/CLI
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest
    
    # audit: создастся, нарушение пишется в audit log
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: latest
```

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
        
        sysctls:                     # ядерные параметры (только разрешённые safe sysctls)
          - name: net.core.somaxconn
            value: "1024"

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
# CAP_NET_RAW, CAP_SYS_CHROOT, CAP_MKNOD, CAP_AUDIT_WRITE

# Принцип: drop ALL, добавить только нужные
# Типичные нужные:
# NET_BIND_SERVICE  — слушать порты < 1024 (nginx :80)
# SYS_PTRACE        — профилировщики, отладчики (НЕ в prod)
# SYS_ADMIN         — опасно, почти = root
```

## Seccomp профили

```bash
# Default RuntimeDefault профиль — блокирует ~300 из ~350 syscalls

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

## OPA Gatekeeper — admission control

```yaml
# Kyverno policy: запретить запуск как root
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-non-root
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: check-runAsNonRoot
      match:
        any:
          - resources:
              kinds: [Pod]
      validate:
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
    kinds: [{apiGroups: ["apps"], kinds: ["Deployment"]}]
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
