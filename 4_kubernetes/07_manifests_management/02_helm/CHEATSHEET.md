# Helm — шпаргалка

Подробности и объяснения — в [helm.md](./01_theory/helm.md).
⚠️ — опасная команда или частая ловушка. Флаги — Helm 3; отличия Helm 4
вынесены в отдельную таблицу.

## Репозитории и чарты

| Задача | Команда |
| :--- | :--- |
| Добавить / обновить репозиторий | `helm repo add prometheus-community https://prometheus-community.github.io/helm-charts`<br>`helm repo update` |
| Найти чарт и версии | `helm search repo kube-prometheus-stack --versions` |
| Значения по умолчанию | `helm show values prometheus-community/kube-prometheus-stack > values.yaml` |
| Скачать и распаковать | `helm pull prometheus-community/kube-prometheus-stack --version <ver> --untar` |
| Чарт из OCI-registry | `helm install myapp oci://registry.example.com/charts/myapp --version 1.2.0` |
| Новый чарт-каркас | `helm create mychart` |

⚠️ Бесплатный каталог Bitnami с 2025 года урезан (старые образы — в
`bitnamilegacy`): проверяйте, что чарт и образы ещё обновляются.

## Рендер и проверка без кластера

| Задача | Команда |
| :--- | :--- |
| Синтаксис и структура | `helm lint ./chart --strict -f values-prod.yaml` |
| Отрендерить в YAML | `helm template myapp ./chart -f values-prod.yaml > out.yaml` |
| Только один шаблон | `helm template myapp ./chart -s templates/deployment.yaml` |
| Подставить версию k8s для `.Capabilities` | `helm template myapp ./chart --kube-version 1.30.0` |
| Подставить доступные API | `helm template myapp ./chart --api-versions monitoring.coreos.com/v1` |
| Unit-тесты шаблонов (плагин) | `helm unittest ./chart` |
| Несколько релизов одним файлом ([helmfile](./02_examples/helmfile.yaml.gotmpl)) | `helmfile -f helmfile.yaml.gotmpl -e dev build` → `diff` → `apply` |

## Установка и обновление

| Задача | Команда |
| :--- | :--- |
| Идемпотентный деплой (стандарт для CI) | `helm upgrade --install myapp ./chart -n prod --create-namespace -f values-prod.yaml` |
| Ждать готовности подов, иначе `failed` | `... --wait --timeout 10m` (Jobs: `--wait-for-jobs`) |
| Откат при неудаче | `... --atomic` (включает `--wait`) |
| Удалить новые ресурсы при неудаче | `... --cleanup-on-fail` |
| Значение из файла (пароли, сертификаты) | `--set-file db.password=/dev/shm/pass` |
| Строка без приведения типов | `--set-string image.tag=0123` |
| Сколько ревизий хранить | `--history-max 10` (по умолчанию 10) |
| Diff перед upgrade (плагин helm-diff) | `helm diff upgrade myapp ./chart -f values-prod.yaml` |
| Секреты через SOPS (плагин helm-secrets) | `helm secrets upgrade --install myapp ./chart -f secrets.yaml` |

| Values при upgrade | Поведение |
| :--- | :--- |
| ничего не указано | values чарта + то, что передано сейчас |
| `--reuse-values` ⚠️ | values прошлого релиза + новые; новые дефолты чарта теряются |
| `--reset-then-reuse-values` | дефолты нового чарта + values прошлого релиза + новые |
| `--reset-values` | только дефолты чарта + новые |

⚠️ `--set` парсит `,` `.` `=` в значении как синтаксис; `--set-string`
от этого не спасает — используйте `--set-file` или `-f`.
⚠️ Любое переданное значение попадает в Secret релиза
`sh.helm.release.v1.<name>.v<N>` — его читает всякий, кто читает Secrets
в namespace.

## Состояние релизов и откат

| Задача | Команда |
| :--- | :--- |
| Все релизы | `helm list -A` (зависшие: `--pending`, упавшие: `--failed`) |
| Статус релиза | `helm status myapp -n prod` |
| История ревизий | `helm history myapp -n prod` |
| Какие values применены | `helm get values myapp -n prod` (с дефолтами: `--all`) |
| Отрендеренный манифест ревизии | `helm get manifest myapp -n prod --revision 5` |
| Хуки релиза | `helm get hooks myapp -n prod` |
| Откатиться на ревизию ⚠️ (дрейф от Git) | `helm rollback myapp 5 -n prod` |
| Удалить релиз ⚠️ | `helm uninstall myapp -n prod` (с историей: `--keep-history`) |
| Секреты релизов | `kubectl get secret -n prod -l owner=helm` |

## Зависимости, хуки, шаблоны

| Задача | Как |
| :--- | :--- |
| Подтянуть сабчарты из `Chart.yaml` | `helm dependency update ./chart` (по lock-файлу: `helm dependency build`) |
| Values сабчарта из родителя | ключ с именем сабчарта: `redis: {auth: {password: ...}}` |
| Миграция БД до upgrade | Job с `helm.sh/hook: pre-upgrade` |
| Не падать на `Job already exists` | `helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded` |
| Порядок хуков | `helm.sh/hook-weight: "-5"` (меньше — раньше) |
| Рестарт подов при смене ConfigMap | `checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . \| sha256sum }}` |
| Запрет на старом кластере | `{{ if semverCompare "<1.25.0" .Capabilities.KubeVersion.Version }}{{ fail "need 1.25+" }}{{ end }}` |
| Обязательное значение | `{{ required "image.tag is required" .Values.image.tag }}` |

## Helm 4: что переименовано

| Helm 3 | Helm 4 |
| :--- | :--- |
| `--atomic` | `--rollback-on-failure` (включает `--wait=watcher`) |
| `--force` | `--force-replace` |
| `--wait` (булев) | `--wait=watcher\|legacy`, по умолчанию `hookOnly` |
| client-side 3-way merge | `--server-side=auto\|true\|false` (SSA для новых релизов) |

## Симптом → куда смотреть

| Симптом | Причина / проверка |
| :--- | :--- |
| `deployed`, а поды в CrashLoopBackOff | upgrade без `--wait`: Helm ждёт только ответа API |
| `another operation (install/upgrade/rollback) is in progress` | релиз завис в `pending-*`: `helm history`, затем `helm rollback` на последнюю `deployed` |
| `Job "migrate" already exists` | политика хука задана без `before-hook-creation` (дефолт) или Job не помечена как хук |
| ConfigMap обновился, поды старые | нет `checksum/config` в аннотации шаблона пода |
| `helm ls` пуст, а приложение есть | ставил Argo CD (`helm template` + apply) |
| `invalid ownership metadata` | ресурс создан не этим релизом: удалить или передать (Helm 4: `--take-ownership`) |

> Проверка: флаги сверены с `helm --help` v3.17.4 и `alpine/helm:4.0.0`
> (docker); не проверено: команды плагинов `helm diff`, `helm secrets`,
> `helm unittest` (плагины не установлены).
