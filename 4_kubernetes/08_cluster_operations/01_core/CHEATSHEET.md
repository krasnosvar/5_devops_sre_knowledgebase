# Эксплуатация кластера — шпаргалка

Подробности и объяснения — в
[cluster_operations.md](./01_theory/cluster_operations.md). Скрипт-обход
проблем — [troubleshoot.sh](./02_examples/troubleshoot.sh).
⚠️ — опасная команда или частая ловушка.

## Cordon / drain

| Задача | Команда |
| :--- | :--- |
| Запретить новые поды на ноде | `kubectl cordon node1` (`spec.unschedulable: true`) |
| Вернуть ноду в работу | `kubectl uncordon node1` |
| Выселить поды через Eviction API (с учётом PDB) | `kubectl drain node1 --ignore-daemonsets --delete-emptydir-data` |
| Ограничить ожидание | `... --timeout=10m --grace-period=60` |
| Посмотреть, что будет выселено | `kubectl drain node1 --ignore-daemonsets --dry-run=client` |
| Поды на ноде | `kubectl get pods -A -o wide --field-selector spec.nodeName=node1` |
| Кто блокирует drain | `kubectl get pdb -A` (смотреть `ALLOWED DISRUPTIONS` = 0) |
| Голые поды без контроллера ⚠️ | `--force` — удалит их навсегда |
| Мимо PDB ⚠️ | `--disable-eviction` — обычный delete, PDB игнорируется |

| Флаг drain | Зачем |
| :--- | :--- |
| `--ignore-daemonsets` | без него drain падает: DaemonSet-поды не выселить |
| `--delete-emptydir-data` | поды с `emptyDir` иначе блокируют drain; данные теряются ⚠️ |
| `--pod-selector='app!=db'` | выселять только часть подов |

## Апгрейд kubeadm-кластера

| Шаг | Команда |
| :--- | :--- |
| 1. Обновить пакет `kubeadm` на первом control plane | пакетным менеджером до целевого патча |
| 2. План и проверка | `kubeadm upgrade plan` |
| 3. Обновить control plane (static pods, сертификаты) | `kubeadm upgrade apply v1.34.1` |
| 4. Остальные control plane ноды | `kubeadm upgrade node` |
| 5. Каждая нода: вывести | `kubectl drain <node> --ignore-daemonsets` |
| 6. Worker: обновить конфиг kubelet | `kubeadm upgrade node` |
| 7. Обновить `kubelet`/`kubectl`, перезапустить | `systemctl daemon-reload && systemctl restart kubelet` |
| 8. Вернуть | `kubectl uncordon <node>` |
| Что изменит в манифестах | `kubeadm upgrade diff` (или `kubeadm upgrade apply ... --dry-run`) |

| Version skew (для kubeadm) | Значение |
| :--- | :--- |
| Шаг минорной версии | строго +1 (1.32 → 1.33 → 1.34) |
| Кто обновляется первым | `kube-apiserver` (control plane) |
| kubelet старее apiserver | до 3 минорных версий (с 1.28; раньше 2) |
| kubelet новее apiserver | нельзя |
| Static pods control plane | `/etc/kubernetes/manifests/` |

## Бэкапы

| Задача | Команда |
| :--- | :--- |
| Снапшот etcd (на control plane) | `etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key snapshot save /backup/etcd.db` |
| Проверить снапшот | `etcdutl snapshot status /backup/etcd.db -w table` |
| Восстановить в новый data-dir ⚠️ | `etcdutl snapshot restore /backup/etcd.db --data-dir /var/lib/etcd-restore` → поправить `hostPath` в `etcd.yaml` |
| Здоровье etcd | `etcdctl ... endpoint health` / `endpoint status -w table` |
| Бэкап namespace (Velero) | `velero backup create app-bk --include-namespaces app --ttl 720h` |
| Восстановить в другой namespace | `velero restore create --from-backup app-bk --namespace-mappings app:app-restore` |
| Регулярно | `velero schedule create daily --schedule="0 3 * * *" --include-namespaces app` |

⚠️ В etcd 3.6 `snapshot status/restore` есть только в `etcdutl`
(`etcdctl` оставил `snapshot save`).

| | etcd snapshot | Velero |
| :--- | :--- | :--- |
| Уровень | вся БД кластера | объекты через API + снапшоты PV (CSI) |
| Частичное восстановление | нет | namespace, тип ресурса |
| Данные томов | нет | да |
| Когда | DR control plane | миграция, откат приложения, DR данных |

## Сертификаты kubeadm

| Задача | Команда |
| :--- | :--- |
| Сроки всех сертификатов | `kubeadm certs check-expiration` |
| Продлить все ⚠️ | `kubeadm certs renew all`, затем перезапустить static pods control plane |
| Где лежат | `/etc/kubernetes/pki/` (CA — 10 лет, остальные — 1 год) |
| Срок конкретного | `openssl x509 -enddate -noout -in /etc/kubernetes/pki/apiserver.crt` |

## Статусы подов: куда смотреть

| Статус | Что значит | Смотреть |
| :--- | :--- | :--- |
| `CrashLoopBackOff` | контейнер падает, backoff 10s → … → 5 мин | `kubectl logs <pod> --previous`, `describe` → `Last State` |
| `OOMKilled`, exit 137 | превышен `limits.memory`, SIGKILL от ядра | `describe` → `Reason: OOMKilled`; поднять лимит или искать утечку |
| `Pending` | scheduler не нашёл ноду | `describe` → `Events` (`Insufficient memory`, taint, PVC) |
| `ImagePullBackOff` / `ErrImagePull` | образ не скачать | `describe` → `Events` (401, `manifest unknown`, сеть) |
| Нода `NotReady` | нет heartbeat ~40–50 с | `kubectl describe node`, на ноде `journalctl -u kubelet` |

⚠️ `kubectl logs` — что внутри контейнера; `describe` (Events) — что
вокруг: scheduling, pull, лимиты. Для `Pending` логов нет.

## Типичные значения

| Параметр | Значение |
| :--- | :--- |
| Toleration к `unreachable`/`not-ready` | 300 с, затем выселение |
| `terminationGracePeriodSeconds` | 30 с |
| Graceful Node Shutdown | `shutdownGracePeriod` / `shutdownGracePeriodCriticalPods` в KubeletConfiguration |

> Проверка: флаги `kubectl drain` (v1.34.1), `kubeadm upgrade/certs`
> (бинарник v1.34.1 в scratch), `etcdctl`/`etcdutl` (образ etcd v3.6.4),
> `velero backup/restore` (образ v1.17.0) сверены по `--help`; не
> проверено: реальный апгрейд и restore (нет kubeadm-кластера).
