# Один кластер или много — шпаргалка

Подробности и объяснения — в
[single_vs_multi_cluster.md](./01_theory/single_vs_multi_cluster.md).
⚠️ — опасная команда или частая ловушка.

## Пороги одного кластера (upstream, ориентиры)

| Параметр | Значение |
| :--- | :--- |
| Нод | до 5000 |
| Подов на ноду | до 110 (дефолт `maxPods` kubelet) |
| Подов всего | до 150 000 |
| Контейнеров всего | до 300 000 |
| Квота БД etcd | 2 GiB по умолчанию (`--quota-backend-bytes`), рекомендуемый максимум 8 GiB |

## Что упирается первым

| Компонент | Почему | Чем смягчают |
| :--- | :--- | :--- |
| etcd | Raft, запись последовательна; размер БД бьёт по latency | меньше объектов и частых апдейтов статуса CRD, дефрагментация |
| kube-apiserver | число `watch`, LIST больших коллекций | горизонтально (stateless), API Priority & Fairness |
| kube-scheduler | filtering + scoring по всем нодам | меньше нод на кластер, профили scheduler |

## Проверить здоровье etcd и API

| Задача | Команда |
| :--- | :--- |
| Размер БД и лидер | `etcdctl endpoint status --cluster -w table` |
| Алармы (NOSPACE) | `etcdctl alarm list` |
| Дефрагментация ⚠️ (блокирует член на время) | `etcdctl defrag --endpoints=<один endpoint>` |
| Сколько объектов по типам | метрика `apiserver_storage_objects` |
| Latency запросов к API | `apiserver_request_duration_seconds` |
| Задержка планирования | `scheduler_scheduling_attempt_duration_seconds` |

## Паттерны разделения

| Паттерн | Когда | Цена |
| :--- | :--- | :--- |
| per-environment (dev/stage/prod) | почти всегда | +2 кластера |
| per-region | гео-latency, резидентность данных | GSLB/Route 53/anycast, N регионов |
| per-tenant | особый SLA/compliance «жирного» клиента | N апгрейдов, N мониторингов |
| per-tier | изоляция критичного (платежи) от общего | дублирование платформенных компонентов |

## Один кластер с multi-tenancy или много

| Критерий | Namespace multi-tenancy | Отдельные кластеры |
| :--- | :--- | :--- |
| Изоляция | логическая | физическая (свой control plane, etcd, CNI) |
| Blast radius | весь кластер (CNI, webhook, апгрейд) | один кластер |
| Стоимость эксплуатации | низкая | N× без слоя управления флотом |
| Резидентность данных | ⚠️ не решает (один control plane) | решает |
| Механизмы | Namespace, ResourceQuota/LimitRange, RBAC, NetworkPolicy (default-deny), PSA/Kyverno/Gatekeeper | CAPI, GitOps на флот |

## Управление флотом

| Задача | Инструмент |
| :--- | :--- |
| Жизненный цикл кластеров как CRD | Cluster API (`Cluster`, `MachineDeployment`) |
| Размещение приложения по кластерам | Karmada (KubeFed архивирован) |
| GitOps на N кластеров волнами | Argo CD ApplicationSet, Flux |
| Edge/большие флоты | Rancher Fleet |

## Чеклист решения

| Вопрос | Если «да» |
| :--- | :--- |
| Compliance требует данные в юрисдикции? | отдельный кластер, альтернатив нет |
| Авария одной команды не должна задеть другую? | разделять |
| Нет ресурсов на N апгрейдов и нет GitOps-флота? | multi-tenancy в одном кластере |
| Измеренная нагрузка у порогов из таблицы выше? | разделять по производительности |
| Нужно только ограничить доступ dev к prod? | может хватить RBAC + namespace |

## Ловушки

- ⚠️ Один GitOps-push сразу на все кластеры превращает флот обратно
  в один домен отказа — раскатывать волнами, canary-кластер первым.
- ⚠️ Node pool в другом регионе ≠ резидентность: etcd и control plane
  остаются в одном месте.
- ⚠️ NetworkPolicy по умолчанию ничего не запрещает — нужен default-deny.

> Проверка: квота 2 GiB и `etcdctl endpoint status --cluster`, `alarm
> list`, `defrag` — по `--help` образа `quay.io/coreos/etcd:v3.6.4`;
> не проверено: пороги масштабируемости (по памяти, upstream «Considerations
> for large clusters»), имена метрик apiserver/scheduler на живом кластере.
