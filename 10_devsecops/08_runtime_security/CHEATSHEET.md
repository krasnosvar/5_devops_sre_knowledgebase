# Runtime Security — шпаргалка

Подробности и объяснения — в
[01_theory/runtime_security.md](./01_theory/runtime_security.md).
⚠️ — опасная команда или частая ловушка.

## Falco: драйверы

| `driver.kind` | Когда |
| :--- | :--- |
| `modern_ebpf` | по умолчанию на современных ядрах: CO-RE, встроен в Falco, нужен BTF (≈5.8+) |
| `ebpf` | legacy probe, устаревает |
| `kmod` | старые ядра без BTF |
| `auto` | значение чарта по умолчанию: выбирает `modern_ebpf`, если ядро позволяет |

## Falco: установка и CLI

| Задача | Команда |
| :--- | :--- |
| Установить в k8s | `helm install falco falcosecurity/falco -n falco --create-namespace --set driver.kind=modern_ebpf --set falcosidekick.enabled=true` |
| Алерты в Slack | `--set falcosidekick.config.slack.webhookurl=https://hooks.slack.com/...` |
| Свои правила через чарт | `-f custom-rules.yaml` (values: `customRules: {custom.yaml: \|-  <правила>}`) |
| Проверить синтаксис правил | `falco -V /etc/falco/falco_rules.yaml -V custom.yaml` |
| Список правил / одно правило | `falco -L` / `falco -l "Terminal shell in container"` |
| Все поля (для condition/output) | `falco --list` (`--list=syscall`) |
| Переопределить опцию | `falco -o json_output=true` |
| Версия, драйвер, конфиг | `falco --support` |
| Алерты в кластере | `kubectl logs -n falco -l app.kubernetes.io/name=falco -c falco -f` |
| Проверить срабатывание | `kubectl exec -it <pod> -- sh` → в логах Falco `Terminal shell in container` |

## Falco: правило

```yaml
- list: allowed_shell_images
  items: [docker.io/library/busybox]

- rule: Shell in prod container
  desc: Interactive shell spawned in a container
  condition: >
    spawned_process and container
    and proc.name in (shell_binaries) and proc.tty != 0
    and not container.image.repository in (allowed_shell_images)
  output: >
    Shell in container (user=%user.name cmd=%proc.cmdline
    container=%container.name image=%container.image.repository
    ns=%k8s.ns.name pod=%k8s.pod.name)
  priority: WARNING
  tags: [container, shell, mitre_execution]
```

| Элемент | Примеры |
| :--- | :--- |
| Макросы из стандартных правил | `spawned_process`, `container`, `open_read`, `open_write`, `sensitive_files`, `shell_procs` |
| Поля процесса | `proc.name`, `proc.cmdline`, `proc.pname`, `proc.tty`, `user.name` |
| Поля файла / сети | `fd.name`, `fd.sip`, `fd.sport`, `evt.type` |
| Поля контейнера / k8s | `container.id`, `container.image.repository`, `k8s.ns.name`, `k8s.pod.name` |
| Приоритеты | `EMERGENCY` … `CRITICAL`, `ERROR`, `WARNING`, `NOTICE`, `INFORMATIONAL`, `DEBUG` |

## Audit log API server

| Флаг kube-apiserver | Типичное значение |
| :--- | :--- |
| `--audit-policy-file` | `/etc/kubernetes/audit/audit-policy.yaml` |
| `--audit-log-path` | `/var/log/kubernetes/audit/audit.log` |
| `--audit-log-maxage` / `-maxbackup` / `-maxsize` | `30` дней / `10` файлов / `100` МБ |

| `level` | Что пишется |
| :--- | :--- |
| `None` | ничего (шумные read-only запросы) |
| `Metadata` | кто, что, когда, ответ — без тел |
| `Request` | + тело запроса |
| `RequestResponse` | + тело ответа (RBAC, `pods/exec`) |

⚠️ Правила policy применяются по первому совпадению — частные правила
выше общего `- level: Metadata`. ⚠️ `RequestResponse` на `secrets`
пишет значения секретов в лог — для secrets достаточно `Metadata`.

| Задача | Команда |
| :--- | :--- |
| Кто делал exec | `jq 'select(.objectRef.subresource=="exec") \| {user: .user.username, pod: .objectRef.name, ns: .objectRef.namespace}' audit.log` |
| Кто читал secrets | `jq 'select(.objectRef.resource=="secrets" and .verb=="get") \| .user.username' audit.log` |

## Инцидент в контейнере: порядок

| Шаг | Команда |
| :--- | :--- |
| 1. Найти Pod, нода, образ | `kubectl get pod <pod> -n <ns> -o wide`<br>`kubectl get pod <pod> -o jsonpath='{.spec.containers[*].image}{"\n"}{.status.containerStatuses[*].imageID}'` |
| 2. Улики до остановки | `kubectl describe pod <pod> > describe.txt`<br>`kubectl logs <pod> --all-containers --previous > logs.txt` |
| 3. Отвязать от Service/ReplicaSet | `kubectl label pod <pod> app- quarantine=true` |
| 4. Изолировать сеть | NetworkPolicy `podSelector: {matchLabels: {quarantine: "true"}}`, `policyTypes: [Ingress, Egress]` |
| 5. Процессы и сокеты | `kubectl exec <pod> -- ps aux` / `kubectl exec <pod> -- ss -tunap` |
| 6. Без shell в образе | `kubectl debug -it <pod> --image=nicolaka/netshoot --target=<container>` |
| 7. На ноде | `crictl ps --name <container>` / `crictl inspect <id>` / `crictl logs <id>` |
| 8. Образ → скан, потом удалить Pod | `trivy image <image@digest>` → `kubectl delete pod <pod>` |

## Ловушки

| ⚠️ | Суть |
| :--- | :--- |
| Удалить Pod сразу | теряются процессы, память, временные файлы — сначала улики |
| Deny-политика «поверх» allow | политики суммируются (OR): нужно снять метки, по которым Pod выбирают allow-политики |
| `kubectl exec` в скомпрометированный Pod | бинарники внутри могут быть подменены; надёжнее `kubectl debug` со своим образом |
| Falco на ядре без BTF с `modern_ebpf` | драйвер не стартует — `kmod` или `auto` |
| Шумные правила | исключения через `list`/`macro` (`append`/override), а не выключение правила |

> Проверка: правило выше прошло `falco -V` (Falco 0.41.3) вместе со
> стандартными; поля — `falco --list`; ключи чарта (`driver.kind`,
> `falcosidekick.*`) — `helm show values` (чарт 9.2.0); не проверено:
> audit-policy и jq-фильтры на живом apiserver, `crictl`.
