# ArgoCD: Application, ApplicationSet, SyncWaves

## Содержание
1. [Архитектура: Application и Reconciliation](#1-архитектура-application-и-reconciliation)
2. [Управление множеством кластеров: ApplicationSet и App-of-Apps](#2-управление-множеством-кластеров-applicationset-и-app-of-apps)
3. [SyncWaves и Sync Hooks: управление порядком деплоя](#3-syncwaves-и-sync-hooks-управление-порядком-деплоя)
4. [ArgoCD и Helm: чем это отличается от `helm install`](#4-argocd-и-helm-чем-это-отличается-от-helm-install)
5. [Типовые вопросы на собеседовании (Interview Q&A)](#5-типовые-вопросы-на-собеседовании-interview-qa)

> Общая теория GitOps (Push/Pull, Drift) — в [`../../01_theory/`](../../01_theory/).
> Альтернатива — [`../../03_fluxcd/`](../../03_fluxcd/).

---

## 1. Архитектура: Application и Reconciliation

В ArgoCD основной объект — Custom Resource `Application`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-production
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/org/gitops-config.git
    targetRevision: HEAD
    path: overlays/production      # сырой YAML, Helm или Kustomize — Source понимает всё
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true       # удалять ресурсы, удалённые из git
      selfHeal: true    # восстанавливать при ручных изменениях
```

ArgoCD держит в памяти кэш манифестов из Git и кэш реального состояния кластера. Reconciliation Loop проверяет дельту между ними. Если они не совпадают — статус становится `OutOfSync`. Если включён `selfHeal`, Argo выполняет синхронизацию (аналог `kubectl apply`) автоматически.

## 2. Управление множеством кластеров: ApplicationSet и App-of-Apps

Как задеплоить 100 микросервисов в 5 разных кластеров, не создавая 500 `Application` руками?

- **App-of-Apps** — паттерн бутстраппинга: создаётся одно корневое `Application`, которое указывает в Git на директорию с манифестами **других** `Application`. ArgoCD синхронизирует корень, создаёт дочерние Application, и те рекурсивно начинают синхронизировать свои целевые сервисы.
- **ApplicationSet** — более современный подход (генератор). Один шаблон + генератор (список кластеров, список директорий в Git, Git-теги) — и ApplicationSet автоматически создаёт десятки `Application` из одного описания:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: myapp-envs
spec:
  generators:
    - list:
        elements:
          - env: dev
          - env: staging
          - env: production
  template:
    metadata:
      name: "myapp-{{env}}"
    spec:
      source:
        repoURL: https://github.com/org/gitops-config.git
        path: "overlays/{{env}}"
      destination:
        namespace: "{{env}}"
      syncPolicy:
        automated:
          selfHeal: "{{env != 'production'}}"   # prod — только manual sync
```

## 3. SyncWaves и Sync Hooks: управление порядком деплоя

ArgoCD применяет манифесты не строго последовательно из файла (см. [`../../../09_manifests_management/`](../../../09_manifests_management/) §5), а по явным волнам. Аннотация `argocd.argoproj.io/sync-wave: "-1"` заставляет ресурс (например, CRD) примениться раньше, чем ресурсы волны `0` (например, CR, использующий эту CRD) — ArgoCD дожидается, пока предыдущая волна станет `Healthy`, прежде чем начать следующую.

## 4. ArgoCD и Helm: чем это отличается от `helm install`

Когда вы делаете `helm install`, Helm создаёт секрет "Релиз" в кластере и сам управляет циклом апгрейда (см. [`../../../09_manifests_management/02_helm/`](../../../09_manifests_management/02_helm/)). ArgoCD же использует Helm только как **шаблонизатор**: делает `helm template`, получает сырой YAML и применяет его через обычный `kubectl apply`/SSA. По умолчанию ArgoCD не создаёт Helm-релизов — команда `helm ls` в кластере ничего не покажет, хотя приложение из чарта работает.

---

## 5. Типовые вопросы на собеседовании (Interview Q&A)

**1. В чём разница подходов к рендерингу манифестов между Helm (в классическом виде) и ArgoCD?**
*Ответ:* Когда вы делаете `helm install`, Helm создаёт секрет "Релиз" в кластере k8s и сам управляет циклом апгрейда. ArgoCD же использует Helm только как **шаблонизатор** — делает `helm template`, генерирует "плоский" сырой YAML и применяет его через `kubectl apply`. По умолчанию ArgoCD не создаёт секретов Helm-релизов в кластере, поэтому команда `helm ls` ничего не покажет, хотя приложение из чарта работает.

**2. Объясните паттерн "App-of-Apps" в ArgoCD. Зачем он нужен?**
*Ответ:* Это паттерн бутстраппинга целых кластеров. Вы не хотите создавать 50 манифестов `Application` руками через UI. Вместо этого вы создаёте в Git один корневой `Application`, который смотрит на директорию, где лежат манифесты других, дочерних `Application` (ingress, monitoring, backend). ArgoCD синхронизирует корень, создаёт в кластере 50 объектов `Application`, и те начинают синхронизировать свои целевые микросервисы.

**3. Если в ArgoCD выключить Auto-Sync, зачем вообще его использовать?**
*Ответ:* Даже без Auto-Sync ArgoCD даёт огромную ценность в виде наблюдаемости и аудита. В UI вы (или QA/Security команда) наглядно видите статус `OutOfSync`, показывающий diff между Git и продакшеном. Вы запускаете синхронизацию нажатием одной кнопки (Manual Sync) — это даёт жёсткий контроль над моментом релиза (Maintenance Windows), сохраняя преимущества Git как источника истины.

**4. Что произойдёт, если ArgoCD попытается синхронизировать манифест с CRD, а контроллер (Operator) для этого CRD ещё не успел зарегистрировать тип ресурса?**
*Ответ:* Попытка применения завершится ошибкой (`resource kind not recognized`), и синхронизация упадёт. Для управления порядком деплоя в ArgoCD используется система `SyncWaves` и Sync Hooks. Манифест с CRD помечается аннотацией `argocd.argoproj.io/sync-wave: "-1"`, чтобы примениться в первую волну, а ресурсы, использующие этот CRD (волна `0`), будут ждать, пока CRD не зарегистрируется в API кластера.

**5. Чем `ApplicationSet` архитектурно лучше подхода "App-of-Apps" при деплое в 20 кластеров?**
*Ответ:* App-of-Apps требует вручную поддерживать в Git манифест `Application` под каждый кластер/окружение — при добавлении 21-го кластера нужно руками написать ещё один YAML. `ApplicationSet` — генератор: он один раз описывает шаблон и правило (список кластеров, список Git-директорий), а сами объекты `Application` создаёт автоматически контроллер ApplicationSet. Добавление нового кластера в список генератора автоматически создаёт для него новый `Application`, без правки лишних файлов.
