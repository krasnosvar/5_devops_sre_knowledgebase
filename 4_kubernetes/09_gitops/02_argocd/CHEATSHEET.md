# Argo CD — шпаргалка

Подробности и объяснения — в [argocd.md](./01_theory/argocd.md), пример —
[argocd-app.yaml](./02_examples/argocd-app.yaml).
⚠️ — опасная команда или частая ловушка.

## Доступ и вход

| Задача | Команда |
| :--- | :--- |
| UI/API локально | `kubectl port-forward svc/argocd-server -n argocd 8080:443` |
| Пароль `admin` после установки | `argocd admin initial-password -n argocd` |
| Войти | `argocd login localhost:8080 --username admin --insecure` |
| Через SSO | `argocd login cd.example.com --sso` |
| Без API-сервера, напрямую в k8s | `argocd login --core` |
| За прокси без HTTP/2 | `--grpc-web` |

## Приложения

| Задача | Команда |
| :--- | :--- |
| Список и статусы | `argocd app list` |
| Детали: Sync, Health, ресурсы | `argocd app get myapp` (обновить из Git: `--refresh`, со сбросом кэша манифестов: `--hard-refresh`) |
| Diff Git ↔ кластер | `argocd app diff myapp` |
| Diff локальных правок до коммита | `argocd app diff myapp --local ./overlays/prod` |
| Синхронизировать | `argocd app sync myapp` |
| Только изменившиеся ресурсы | `argocd app sync myapp --apply-out-of-sync-only` |
| Один ресурс | `argocd app sync myapp --resource apps:Deployment:myapp` |
| С удалением лишнего ⚠️ | `argocd app sync myapp --prune` |
| Предпросмотр | `argocd app sync myapp --dry-run` |
| Ждать Synced + Healthy (CI) | `argocd app wait myapp --sync --health --timeout 300` |
| История и откат ⚠️ (не при автосинке) | `argocd app history myapp` → `argocd app rollback myapp <ID>` |
| Отменить зависшую операцию | `argocd app terminate-op myapp` |
| Отрендеренные манифесты | `argocd app manifests myapp` |
| Логи подов приложения | `argocd app logs myapp` |
| Создать из CLI | `argocd app create myapp --repo <url> --path overlays/prod --dest-server https://kubernetes.default.svc --dest-namespace prod` |
| Что сгенерирует ApplicationSet | `argocd appset generate appset.yaml` |
| Проекты | `argocd proj list`, `argocd proj get <proj>` |

## Application: ключевые поля

```yaml
spec:
  project: default
  source: {repoURL: https://github.com/org/gitops-config.git, targetRevision: HEAD, path: overlays/production}
  destination: {server: https://kubernetes.default.svc, namespace: production}
  syncPolicy:
    automated: {prune: true, selfHeal: true}
    syncOptions: [CreateNamespace=true, ServerSideApply=true]
  ignoreDifferences:
    - {group: apps, kind: Deployment, jsonPointers: [/spec/replicas]}
```

| Поле | Без него |
| :--- | :--- |
| `automated` | только ручной sync |
| `prune: true` | удалённое из Git остаётся в кластере |
| `selfHeal: true` | ручные правки не откатываются, автосинк только на коммиты |
| `ignoreDifferences` | вечная борьба с HPA за `replicas` |
| `CreateNamespace=true` | sync падает без namespace |

## Порядок, хуки, аннотации

| Задача | Аннотация на ресурсе |
| :--- | :--- |
| Применить раньше (CRD, namespace) | `argocd.argoproj.io/sync-wave: "-1"` (по умолчанию `0`) |
| Миграция БД до sync | `argocd.argoproj.io/hook: PreSync` (+ `Sync`, `PostSync`, `SyncFail`) |
| Удалять хук | `argocd.argoproj.io/hook-delete-policy: HookSucceeded` (или `BeforeHookCreation`) |
| Не удалять при prune | `argocd.argoproj.io/sync-options: Prune=false` |
| CR, чья CRD ставится в том же sync | `argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true` |
| Не считать OutOfSync сгенерированный объект | `argocd.argoproj.io/compare-options: IgnoreExtraneous` |

Внутри волны порядок: фаза (PreSync → Sync → PostSync) → волна → kind
(Namespace, CRD раньше Deployment) → имя. Следующая волна стартует, когда
предыдущая `Healthy`.

## Когда что

| Задача | Инструмент |
| :--- | :--- |
| Бутстрап кластера набором Application | App-of-Apps |
| Одно приложение × N окружений/кластеров | `ApplicationSet` (`list`, `clusters`, `git` генераторы) |
| Условная структура в ApplicationSet | `goTemplate: true` + `templatePatch` |
| Доверенные команды в одном кластере | один Argo CD + `AppProject` |
| Разные уровни доверия, регуляторка | отдельный Argo CD на команду (namespaced) |

## Симптом → куда смотреть

| Симптом | Причина / проверка |
| :--- | :--- |
| `Synced`, но `Degraded` | приложено то, что в Git, и оно не работает: `argocd app get`, события подов |
| Вечный `OutOfSync` на одном поле | поле меняет контроллер/webhook → `ignoreDifferences` |
| `resource ... not found` / `could not find kind` при sync | CRD в том же sync: sync-wave `-1` + `SkipDryRunOnMissingResource` |
| `helm ls` пуст | Argo CD рендерит через `helm template`, релизов нет |
| Изменения в Git не подхватываются | кэш repo-server: `argocd app get --hard-refresh` |
| `permission denied` / `not permitted in project` | `AppProject`: `sourceRepos`, `destinations`, whitelist ресурсов |
| Rollback не работает | при включённом автосинке запрещён: откат через `git revert` |

> Проверка: подкоманды и флаги сверены с `argocd ... --help` (образ
> `quay.io/argoproj/argocd:v3.1.8`); YAML-фрагмент — `yamllint`; не
> проверено: работа против живого Argo CD.
