# Работа с манифестами — шпаргалка

Подробности и объяснения — в
[manifests_management.md](./01_theory/manifests_management.md).
⚠️ — опасная команда или частая ловушка.

## Анатомия и поиск схемы

| Задача | Команда |
| :--- | :--- |
| Какие ресурсы и версии API есть в кластере | `kubectl api-resources` (только группы: `kubectl api-versions`) |
| Ресурсы одной группы | `kubectl api-resources --api-group=apps` |
| Только namespaced / cluster-scoped | `kubectl api-resources --namespaced=true` / `=false` |
| Документация поля | `kubectl explain deployment.spec.strategy` |
| Все поля дерева | `kubectl explain deployment.spec --recursive` |
| Каркас манифеста без кластера | `kubectl create deployment myapp --image=nginx --dry-run=client -o yaml` |

| `apiVersion` | Ресурсы |
| :--- | :--- |
| `v1` (core, без группы) | Pod, Service, ConfigMap, Secret, PVC, Namespace |
| `apps/v1` | Deployment, StatefulSet, DaemonSet, ReplicaSet |
| `batch/v1` | Job, CronJob |
| `networking.k8s.io/v1` | Ingress, NetworkPolicy |
| `autoscaling/v2` | HorizontalPodAutoscaler |

⚠️ `no matches for kind X in version Y` — устаревший `apiVersion` или
CRD ещё не установлена.

## Labels vs Annotations

| Нужно | Куда | Пример |
| :--- | :--- | :--- |
| Фильтровать, выбирать селектором | label | `kubectl get pods -l app.kubernetes.io/name=myapp` |
| Метаданные для инструмента/контроллера | annotation | `external-dns.alpha.kubernetes.io/hostname`, `checksum/config` |
| Стандартные ключи | label | `app.kubernetes.io/{name,instance,version,component,part-of,managed-by}` |

| Задача | Команда |
| :--- | :--- |
| Повесить / снять label | `kubectl label pod p env=dev` / `kubectl label pod p env-` |
| Перезаписать существующий | `kubectl label pod p env=prod --overwrite` |
| Аннотация | `kubectl annotate deploy myapp note="..."` |
| Показать labels колонками | `kubectl get pods -L app,env` (все: `--show-labels`) |
| Селектор по множеству | `kubectl get pods -l 'env in (dev,stage),tier!=db'` |

## Apply: CSA vs SSA

| Задача | Команда |
| :--- | :--- |
| Client-Side Apply (по умолчанию) | `kubectl apply -f deploy.yaml` |
| Применить каталог рекурсивно | `kubectl apply -f dir/ -R` |
| Server-Side Apply со своим менеджером полей | `kubectl apply -f deploy.yaml --server-side --field-manager=ci-pipeline` |
| Забрать чужие поля при конфликте ⚠️ | `kubectl apply -f deploy.yaml --server-side --force-conflicts` |
| Кто владеет полями | `kubectl get deploy myapp -o yaml --show-managed-fields` |
| Что лежит в last-applied (CSA) | `kubectl apply view-last-applied deploy/myapp` |

| | Client-Side Apply | Server-Side Apply |
| :--- | :--- | :--- |
| Где считается diff | в `kubectl` (3-way: last-applied, файл, live) | на API-сервере |
| Память о прошлом | аннотация `last-applied-configuration` | `metadata.managedFields` |
| Чужое изменение того же поля | молча перезаписывается | `conflict`, нужен `--force-conflicts` |
| Когда | ручные правки, мелкие кластеры | CI, GitOps-агенты, несколько авторов |

## Проверка до применения

| Задача | Команда |
| :--- | :--- |
| Локальная проверка, без API | `kubectl apply -f x.yaml --dry-run=client` |
| Через API: authn/authz, admission, CRD-схема, без записи в etcd | `kubectl apply -f x.yaml --dry-run=server` |
| Дельта live ↔ файл (exit 1 = есть разница) | `kubectl diff -f x.yaml` |
| Diff с SSA | `kubectl diff -f x.yaml --server-side` |
| Итоговый объект после defaulting | `kubectl apply -f x.yaml --dry-run=server -o yaml` |

⚠️ `--dry-run=client` не видит admission-политик (Kyverno/OPA), конфликтов
и CRD, которых нет локально.

## Multi-document и порядок

| Ситуация | Что делать |
| :--- | :--- |
| Несколько ресурсов в файле | разделитель `---`; `apply` шлёт по порядку, **не ждёт** готовности |
| CRD, потом CR | раздельные `apply` + `kubectl wait --for=condition=Established crd/<name>` |
| Дождаться раскатки | `kubectl rollout status deploy/myapp --timeout=120s` |
| Порядок в GitOps | sync-waves Argo CD, `dependsOn` во Flux, hooks в Helm |

## Когда что использовать

| Ситуация | Инструмент |
| :--- | :--- |
| Одно окружение, несколько файлов | `kubectl apply` / SSA |
| Публичный «коробочный» софт, параметры через values | Helm → [CHEATSHEET](./02_helm/CHEATSHEET.md) |
| Свои сервисы, base + оверлеи dev/stage/prod | Kustomize → [CHEATSHEET](./03_kustomize/CHEATSHEET.md) |
| Чужой чарт + свои патчи | Kustomize `helmCharts` |

> Проверка: флаги сверены с `kubectl --help` (v1.34.1, без кластера);
> не проверено: вывод `--show-managed-fields` и `--dry-run=server` (нужен
> кластер).
