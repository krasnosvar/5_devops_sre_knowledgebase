# Первые шаги в Kubernetes — шпаргалка

Подробности и объяснения — в
[first_steps.md](./01_theory/first_steps.md). ⚠️ — опасная команда или
частая ловушка.

## kubeconfig, контексты, namespace

| Задача | Команда |
| :--- | :--- |
| Все контексты (текущий помечен `*`) | `kubectl config get-contexts` |
| Какой контекст активен ⚠️ проверять перед любой правкой | `kubectl config current-context` |
| Переключить контекст | `kubectl config use-context kind-first` |
| Сменить namespace по умолчанию | `kubectl config set-context --current --namespace=dev` |
| Одна команда в другом контексте / namespace | `kubectl --context kind-first -n dev get pods` |
| Другой kubeconfig на одну сессию | `export KUBECONFIG=~/.kube/kind-first` |
| Итоговый конфиг (секреты скрыты) | `kubectl config view --minify` |
| Кто я для API-сервера | `kubectl auth whoami` |
| То же короче (kubectx/kubens) | `kubectx kind-first`, `kubens kube-system` |

## Локальный кластер (kind)

| Задача | Команда |
| :--- | :--- |
| Создать кластер по конфигу | `kind create cluster --name first --config kind-config.yaml` |
| Список кластеров | `kind get clusters` |
| Вернуть kubeconfig кластера | `kind get kubeconfig --name first` |
| Загрузить локальный образ в ноды | `kind load docker-image myapp:dev --name first` |
| Удалить кластер | `kind delete cluster --name first` |

## Посмотреть

| Задача | Команда |
| :--- | :--- |
| Поды текущего namespace | `kubectl get pods` (`po`) |
| + IP пода и нода | `kubectl get pods -o wide` |
| Во всех namespace | `kubectl get pods -A` |
| Несколько типов сразу | `kubectl get deploy,svc,po` |
| Полный объект из API | `kubectl get pod hello -o yaml` |
| Метки и фильтр по ним | `kubectl get pods --show-labels`<br>`kubectl get pods -l app=web` |
| Человекочитаемо + Events | `kubectl describe pod hello` |
| События namespace по времени | `kubectl events` (`kubectl get events --sort-by=.lastTimestamp`) |
| Следить за изменениями | `kubectl get pods -w` |
| Какие ресурсы есть в кластере | `kubectl api-resources` |
| Справка по полю схемы | `kubectl explain deployment.spec.strategy`<br>`kubectl explain pod.spec --recursive` |

## Изменить

| Задача | Команда |
| :--- | :--- |
| Создать/обновить по файлу или каталогу | `kubectl apply -f pod.yaml`<br>`kubectl apply -f ./manifests/` |
| Показать разницу до применения | `kubectl diff -f deployment.yaml` |
| Сгенерировать YAML Deployment | `kubectl create deployment web --image=nginx:1.27-alpine --replicas=2 --dry-run=client -o yaml > deployment.yaml` |
| Сгенерировать YAML Pod | `kubectl run hello --image=nginx:1.27-alpine --dry-run=client -o yaml` |
| Сгенерировать Service | `kubectl expose deployment web --port=80 --target-port=80 --dry-run=client -o yaml` |
| Проверка сервером, без сохранения | `kubectl apply -f x.yaml --dry-run=server` |
| Изменить число копий | `kubectl scale deployment web --replicas=3` |
| Удалить описанное в файле ⚠️ | `kubectl delete -f pod.yaml` |
| Удалить по имени | `kubectl delete pod hello` |

| `--dry-run=` | Что проверено |
| :--- | :--- |
| `client` | только сборка объекта в kubectl, сервер не вызывается |
| `server` | схема, defaulting, admission (PSA, вебхуки политик); в etcd не пишется |

## Заглянуть внутрь

| Задача | Команда |
| :--- | :--- |
| Логи | `kubectl logs hello` |
| Логи упавшего запуска | `kubectl logs hello --previous` |
| Следить за логами пода Deployment | `kubectl logs deploy/web -f` |
| Shell в контейнере | `kubectl exec -it hello -- sh` |
| Одна команда | `kubectl exec hello -- nginx -v` |
| Туннель к поду / Service (один под!) | `kubectl port-forward svc/web 8080:80` |
| Какие поды за Service | `kubectl get endpointslices -l kubernetes.io/service-name=web` |

## Сокращения типов

| Полное | Коротко |
| :--- | :--- |
| pods / deployments / replicasets | `po` / `deploy` / `rs` |
| services / namespaces / nodes | `svc` / `ns` / `no` |
| configmaps / persistentvolumeclaims | `cm` / `pvc` |
| serviceaccounts / ingresses | `sa` / `ing` |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| `No resources found`, хотя «всё работает» | `kubectl config current-context`, флаг `-n` / `-A` |
| Удалённый под вернулся с новым именем | его владелец: `metadata.ownerReferences`; удалять/скейлить Deployment |
| Под `Running`, READY `0/1` | readinessProbe не проходит → `describe pod`, Events |
| Под `Pending` | `describe pod` → Events (`FailedScheduling`) |
| `ImagePullBackOff` | имя/тег образа, доступ к registry — Events |
| `CrashLoopBackOff` | `logs --previous`, `Last State` в `describe` |
| Service есть, трафик не идёт | `selector` Service ≠ labels подов; пустой EndpointSlice |
| `create` вернул `AlreadyExists` | использовать `apply` |

## Ловушки

- ⚠️ Текущий контекст — главный источник аварий: команда для теста уходит
  в прод. Пишите `--context` явно в скриптах.
- ⚠️ `port-forward` не балансирует: туннель через API-сервер к одному поду.
- ⚠️ Голый Pod никто не пересоздаёт — в работе создают Deployment.
- Удаление контекста из kubeconfig не трогает кластер.

> Проверка: флаги сверены с `kubectl <cmd> --help` (kubectl v1.34.1),
> `kind` v0.30.0; генерация YAML и `--dry-run=server` прогнаны на
> временном kind-кластере; не проверено: `kubectx`/`kubens`.
