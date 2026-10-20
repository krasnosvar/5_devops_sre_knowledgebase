# GitOps — шпаргалка

Подробности и объяснения — в [gitops.md](./01_theory/gitops.md).
Команды инструментов: [Argo CD](./02_argocd/CHEATSHEET.md),
[Flux](./03_fluxcd/CHEATSHEET.md),
[Argo Rollouts](./04_argo_rollouts/CHEATSHEET.md).
⚠️ — частая ловушка.

## Четыре принципа OpenGitOps

| Принцип | На практике |
| :--- | :--- |
| Декларативность | манифесты / чарты / оверлеи, а не скрипт из `kubectl` |
| Версионирование и неизменяемость | Git: коммит, ревью, `git revert` |
| Автоматическое получение (pull) | агент сам забирает состояние из Git |
| Непрерывная сверка | агент постоянно чинит расхождения |

## Push vs Pull

| | Push (CI деплоит) | Pull (GitOps-агент) |
| :--- | :--- | :--- |
| Кто ходит в API кластера | раннер CI с kubeconfig | агент внутри кластера |
| Права на запись в прод | в переменных CI ⚠️ | не покидают кластер |
| Входящий доступ к API | нужен раннеру | не нужен, только исходящий к Git |
| Дрейф после деплоя | никто не замечает | виден как `OutOfSync`, чинится |
| Откат | перезапуск старого пайплайна | `git revert` |
| Что защищать | CI-секреты | права записи в Git (protected branches, ревью) |

## Цикл reconciliation

| Шаг | Что происходит |
| :--- | :--- |
| Fetch | ревизия из Git по SHA (опрос раз в минуты или webhook) |
| Render | сырой YAML, `kustomize build`, `helm template` |
| Diff | только поля из Git; `status`, `uid`, defaulting игнорируются |
| Apply | apply / SSA; удаление — только с `prune` |
| Health | Deployment раскатился, поды Ready |

| Статус | Значения | Вопрос |
| :--- | :--- | :--- |
| Sync | `Synced` / `OutOfSync` | совпадает ли кластер с Git |
| Health | `Healthy` / `Progressing` / `Degraded` / `Missing` | работает ли применённое |

⚠️ `Synced` + `Degraded` — нормальная комбинация: в Git ошибка (тег с
опечаткой). Чинить Git (`git revert`), не кластер.

## Аналоги Argo CD ↔ Flux

| Задача | Argo CD | Flux |
| :--- | :--- | :--- |
| Источник + назначение | `Application` | `GitRepository` + `Kustomization` / `HelmRelease` |
| Удалять исчезнувшее из Git | `syncPolicy.automated.prune: true` | `spec.prune: true` |
| Откатывать ручные правки | `selfHeal: true` | по умолчанию на каждом `interval` |
| Не сравнивать поле | `ignoreDifferences` | не указывать поле в Git |
| Порядок применения | `argocd.argoproj.io/sync-wave` | `dependsOn` |
| Много окружений/кластеров | `ApplicationSet`, App-of-Apps | несколько `Kustomization` (`kubeConfig`) |
| Сузить права агента | `AppProject` | `serviceAccountName` у `Kustomization` |
| Обновление образов | Argo CD Image Updater | `ImageRepository` + `ImagePolicy` + `ImageUpdateAutomation` |
| Принудительно сейчас | `argocd app sync <app>` | `flux reconcile kustomization <name> --with-source` |

## Секреты в GitOps

| Подход | В Git лежит | Расшифровывает |
| :--- | :--- | :--- |
| Sealed Secrets | `SealedSecret` (шифротекст) | контроллер в кластере |
| SOPS | зашифрованный YAML | Flux kustomize-controller / плагин Argo CD |
| External Secrets Operator | `ExternalSecret` (ссылка) | ESO берёт из Vault / Secrets Manager |

## Симптом → куда смотреть

| Симптом | Причина / решение |
| :--- | :--- |
| Ресурс удалён из Git, но жив в кластере | выключен `prune` |
| Ручная правка не откатывается (Argo CD) | автосинк без `selfHeal` реагирует только на коммиты |
| `replicas` скачут, вечный `OutOfSync` | HPA vs Git: убрать `replicas` из манифеста или `ignoreDifferences` |
| Коммит есть, деплоя нет минуты | ждёт опроса; настроить webhook (это не push: агент всё равно тянет сам) |
| Всё приложение удалилось | неверный `path` + `prune`: агент «увидел» пустой каталог ⚠️ |

> Проверка: справочная страница; команды сверены в шпаргалках
> инструментов; не проверено: —.
