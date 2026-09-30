# Runtime Security

## Falco — обнаружение аномалий в runtime

Falco — CNCF-проект для обнаружения подозрительного поведения контейнеров в runtime.
Использует eBPF для перехвата syscalls без изменения приложений.

**Что обнаруживает:**
- Запись файлов в неожиданные директории
- Выполнение shell внутри контейнера
- Чтение чувствительных файлов (/etc/shadow, /etc/kubernetes/admin.conf)
- Сетевые соединения из контейнера на неожиданные IP
- Повышение привилегий

```bash
# установить Falco в k8s
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco falcosecurity/falco \
  --namespace falco --create-namespace \
  --set driver.kind=ebpf \
  --set falcosidekick.enabled=true \
  --set falcosidekick.config.slack.webhookurl=https://hooks.slack.com/...
```

```yaml
# Пример Falco правила — обнаружить shell в контейнере
- rule: Terminal shell in container
  desc: A shell was used as the entrypoint/exec point into a container
  condition: >
    spawned_process and container
    and shell_procs and proc.tty != 0
    and not user_expected_terminal_shell_in_container_conditions
  output: >
    A shell was spawned in a container with an attached terminal
    (user=%user.name container=%container.name image=%container.image.repository
     shell=%proc.name parent=%proc.pname cmdline=%proc.cmdline)
  priority: NOTICE
  tags: [container, shell, mitre_execution]

# Обнаружить чтение секретов
- rule: Read sensitive file untrusted
  desc: >
    An attempt to read sensitive files (e.g. /etc/shadow, credential files, etc.)
    was detected
  condition: >
    open_read and sensitive_files and not proc.name in (known_safe_programs)
  output: >
    Sensitive file opened for reading
    (user=%user.name command=%proc.cmdline file=%fd.name)
  priority: WARNING
```

## Kubernetes Audit Log

K8s API server пишет audit log всех запросов.
Важен для forensics: кто что делал с кластером.

```yaml
# kube-apiserver — включить аудит
# /etc/kubernetes/manifests/kube-apiserver.yaml
spec:
  containers:
    - command:
        - kube-apiserver
        - --audit-log-path=/var/log/kubernetes/audit/audit.log
        - --audit-log-maxage=30
        - --audit-log-maxbackup=10
        - --audit-log-maxsize=100
        - --audit-policy-file=/etc/kubernetes/audit/audit-policy.yaml
```

```yaml
# audit-policy.yaml — что логировать
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # Логировать все запросы к secrets
  - level: RequestResponse
    resources:
      - group: ""
        resources: ["secrets"]
  
  # Логировать изменения RBAC
  - level: RequestResponse
    resources:
      - group: "rbac.authorization.k8s.io"
        resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
  
  # Логировать exec в Pod
  - level: RequestResponse
    resources:
      - group: ""
        resources: ["pods/exec", "pods/portforward", "pods/proxy"]
  
  # Не логировать read-only запросы к стандартным ресурсам (много шума)
  - level: None
    verbs: ["get", "list", "watch"]
    resources:
      - group: ""
        resources: ["endpoints", "services", "configmaps"]
  
  # Всё остальное — metadata уровень
  - level: Metadata
```

## Реакция на инциденты в контейнерной среде

```bash
# 1. Идентифицировать подозрительный Pod
kubectl get pods -A | grep -v Running

# 2. Собрать доказательства ДО остановки
kubectl describe pod suspicious-pod -n default > pod-details.txt
kubectl logs suspicious-pod > pod-logs.txt

# 3. Изолировать (убрать трафик, но не убивать)
kubectl patch networkpolicy allow-all -p '{"spec":{"podSelector":{"matchLabels":{"quarantine":"true"}}}}'
kubectl label pod suspicious-pod quarantine=true

# 4. Создать snapshot файловой системы
CONTAINER_ID=$(kubectl get pod suspicious-pod -o jsonpath='{.status.containerStatuses[0].containerID}' | sed 's/containerd:\/\///')
# на ноде:
sudo ctr containers snapshot suspicious-snapshot $CONTAINER_ID

# 5. Анализ запущенных процессов
kubectl exec suspicious-pod -- ps aux
kubectl exec suspicious-pod -- ss -tlnp

# 6. Удалить Pod и проверить образ
kubectl delete pod suspicious-pod
trivy image $(kubectl get pod suspicious-pod -o jsonpath='{.spec.containers[0].image}')

# 7. Проверить если образ был изменён
docker diff suspicious-container-id   # показать изменения ФС
```

## Network Policy для zero-trust

```yaml
# 1. Запретить весь трафик в namespace по умолчанию
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]

---
# 2. Разрешить только необходимое
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-to-db
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: postgres
  policyTypes: [Ingress]
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: api
      ports:
        - port: 5432
```
