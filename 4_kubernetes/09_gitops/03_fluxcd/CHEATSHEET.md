# Flux CD — шпаргалка

Подробности и объяснения — в [fluxcd.md](./01_theory/fluxcd.md), примеры —
[gitrepository-kustomization.yaml](./02_examples/gitrepository-kustomization.yaml),
[helmrelease.yaml](./02_examples/helmrelease.yaml).
⚠️ — опасная команда или частая ловушка. Namespace по умолчанию у CLI —
`flux-system`.

## Установка и проверка

| Задача | Команда |
| :--- | :--- |
| Проверить кластер до установки | `flux check --pre` |
| Bootstrap в GitHub-репозиторий | `flux bootstrap github --owner=<org> --repository=<repo> --branch=main --path=clusters/prod` |
| Личный аккаунт GitHub | `... --owner=<user> --personal` |
| Состояние контроллеров | `flux check` |
| Версии CLI и контроллеров | `flux version` |

## Наблюдение

| Задача | Команда |
| :--- | :--- |
| Всё и сразу | `flux get all -A` |
| Источники Git | `flux get sources git -A` |
| Kustomization / HelmRelease | `flux get kustomizations -A` / `flux get helmreleases -A` |
| Image automation | `flux get images all -A` |
| Откуда пришёл объект кластера | `flux trace deployment/myapp -n prod` |
| Что применила Kustomization | `flux tree kustomization myapp-production` |
| События объекта | `flux events --for Kustomization/myapp-production` |
| Логи ошибок контроллеров | `flux logs --level=error -A` (поток: `--follow`) |
| Логи по объекту | `flux logs --kind=Kustomization --name=myapp-production` |

## Управление

| Задача | Команда |
| :--- | :--- |
| Синхронизировать сейчас (с перечиткой Git) | `flux reconcile kustomization myapp-production --with-source` |
| То же для HelmRelease | `flux reconcile helmrelease podinfo --with-source` |
| Сбросить счётчик неудач HelmRelease | `flux reconcile helmrelease podinfo --reset` (разово переустановить: `--force`) |
| Только источник | `flux reconcile source git gitops-config` |
| Заморозить (ручной хотфикс) ⚠️ | `flux suspend kustomization myapp-production` |
| Вернуть | `flux resume kustomization myapp-production` |
| Отрендерить локально | `flux build kustomization myapp-production --path ./overlays/production` |
| Diff локальных файлов с кластером | `flux diff kustomization myapp-production --path ./overlays/production` |
| Сгенерировать YAML объекта | `flux create source git app --url=<url> --branch=main --export > source.yaml` |
| | `flux create kustomization app --source=GitRepository/app --path=./deploy --prune=true --interval=5m --export` |

⚠️ `suspend` останавливает сверку: забытая приостановка = тихий дрейф.

## Ресурсы и API

| Kind | `apiVersion` | Отвечает за |
| :--- | :--- | :--- |
| `GitRepository`, `OCIRepository`, `HelmRepository`, `Bucket` | `source.toolkit.fluxcd.io/v1` | откуда брать байты |
| `Kustomization` | `kustomize.toolkit.fluxcd.io/v1` | что применить и куда |
| `HelmRelease` | `helm.toolkit.fluxcd.io/v2` | `helm upgrade --install` в кластере |
| `ImageRepository`, `ImagePolicy`, `ImageUpdateAutomation` | `image.toolkit.fluxcd.io/v1` | новые теги → коммит в Git |

⚠️ Flux `Kustomization` (`kustomize.toolkit.fluxcd.io`) и файл
`kustomization.yaml` (`kustomize.config.k8s.io`) — разные сущности.

## Kustomization: ключевые поля

| Поле | Смысл |
| :--- | :--- |
| `interval: 5m` | период сверки; ручные правки откатываются на каждом |
| `sourceRef` | ссылка на `GitRepository`/`OCIRepository` |
| `path: ./overlays/production` | каталог в репозитории |
| `prune: true` | удалять исчезнувшее из Git |
| `targetNamespace` | переопределить namespace объектов |
| `dependsOn: [{name: infra}]` | порядок: сначала `infra` Ready |
| `wait: true` / `healthChecks` | считать Ready только после готовности ресурсов |
| `serviceAccountName` | сузить права применения |
| `decryption: {provider: sops}` | расшифровать SOPS-секреты |
| `kubeConfig` | применять в другой кластер |

| HelmRelease | Смысл |
| :--- | :--- |
| `chart.spec.version: "6.x"` | semver-диапазон, новые версии подтягиваются сами |
| `install/upgrade.remediation.retries` | повторы при неудаче |
| `upgrade.remediation.remediateLastFailure: true` | откатить неудачный upgrade |
| релиз | обычный Helm-релиз, виден в `helm ls` |

Маркер для Image Automation в YAML:
`image: ghcr.io/org/app:1.2.3 # {"$imagepolicy": "flux-system:app"}`

## Симптом → куда смотреть

| Симптом | Причина / проверка |
| :--- | :--- |
| `Kustomization` не Ready, `dependency ... is not ready` | ждёт `dependsOn`: `flux get kustomizations` |
| Новый коммит не применяется | источник не обновился: `flux get sources git`, `flux reconcile ... --with-source` |
| HelmRelease застрял в `RetriesExceeded` | исчерпаны retries: исправить values, `flux reconcile helmrelease ... --reset` |
| Ручная правка исчезла | так и задумано: сверка на каждом `interval` |
| Образ не обновился автоматически | нет маркера `$imagepolicy`, не тот API (`v1beta2` удалён) или нет доступа на push |
| `flux` показывает не тот namespace | по умолчанию `-n flux-system`, для всех: `-A` |

> Проверка: команды и флаги сверены с `flux ... --help` (образ
> `ghcr.io/fluxcd/flux-cli:v2.7.0`); не проверено: bootstrap и работа с
> живым кластером, поведение `--reset`/`--force` на реальном релизе.
