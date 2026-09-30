# Flux CD: Source, Kustomize/Helm Controller, Image Automation

## Содержание
1. [Архитектура: микросервисы вместо монолита](#1-архитектура-микросервисы-вместо-монолита)
2. [GitRepository и Kustomization: два ресурса вместо одного Application](#2-gitrepository-и-kustomization-два-ресурса-вместо-одного-application)
3. [Image Automation Controller](#3-image-automation-controller)
4. [Flux vs ArgoCD: когда что выбрать](#4-flux-vs-argocd-когда-что-выбрать)
5. [Типовые вопросы на собеседовании (Interview Q&A)](#5-типовые-вопросы-на-собеседовании-interview-qa)

> Общая теория GitOps — в [`../../01_theory/`](../../01_theory/). Альтернатива — [`../../02_argocd/`](../../02_argocd/).

---

## 1. Архитектура: микросервисы вместо монолита

Flux v2 (CNCF-проект, философия "GitOps Toolkit") построен из набора узкоспециализированных контроллеров, а не одного бинарника:

- **Source Controller** — единственная его задача: скачать исходники из Git (или Helm OCI-репозитория, или S3-бакета), проверить PGP-подпись коммитов, упаковать в `tar.gz` и раздавать этот артефакт остальным контроллерам внутри кластера по HTTP. Он ничего не знает про Kubernetes-манифесты — только про доставку байтов.
- **Kustomize Controller** / **Helm Controller** — скачивают артефакт от Source Controller, рендерят из него финальные YAML-манифесты (через `kustomize build` или `helm template`) и применяют их в кластер через Server-Side Apply.

В отличие от ArgoCD (один CRD `Application`, один UI из коробки), Flux — это несколько CRD и несколько подов-контроллеров, без графического интерфейса по умолчанию (есть отдельный проект Weave GitOps UI). Это осознанный компромисс: меньше "магии" в одном месте, легче встроить только нужные части (например, взять только Source+Helm Controller, без Kustomize Controller).

## 2. GitRepository и Kustomization: два ресурса вместо одного Application

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: gitops-config
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/org/gitops-config.git
  ref:
    branch: main

---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: myapp-production
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: gitops-config
  path: "./overlays/production"
  prune: true              # аналог ArgoCD prune: true
  targetNamespace: production
```

Там, где в ArgoCD один `Application` описывает и источник (`source`), и назначение (`destination`), и политику синхронизации сразу, Flux разносит это по двум разным ресурсам: `GitRepository` (откуда брать байты) и `Kustomization` (что и куда с ними делать). Один `GitRepository` может обслуживать сразу несколько `Kustomization`, указывающих на разные пути одного репозитория — это ближе к Unix-философии "одна утилита — одна задача", чем к единому объекту ArgoCD.

## 3. Image Automation Controller

Аналог ArgoCD Image Updater, но встроенный в тот же GitOps Toolkit: `ImageRepository` следит за новыми тегами в registry, `ImagePolicy` решает, какой тег считать "новее" (semver, regex), а `ImageUpdateAutomation` сам коммитит обновлённый тег обратно в Git-репозиторий с манифестами — тот самый паттерн Write-back из общей теории GitOps.

## 4. Flux vs ArgoCD: когда что выбрать

| | ArgoCD | Flux |
|---|---|---|
| UI из коробки | Да, полноценный веб-UI | Нет (Weave GitOps — отдельно) |
| Модель ресурсов | Один `Application` на всё | `GitRepository` + `Kustomization`/`HelmRelease` раздельно |
| Мультикластер | ApplicationSet / App-of-Apps | Несколько `Kustomization`, каждая со своим `kubeConfig` |
| Философия | Централизованная платформа с UI для команд | Набор Unix-way контроллеров, встраиваемых по частям |

Оба — полноценные CNCF-проекты, оба поддерживают Helm и Kustomize как источник. Выбор чаще определяется тем, нужен ли команде готовый UI "из коробки" (ArgoCD) или предпочтителен минималистичный, полностью декларативный стек без графического интерфейса (Flux).

---

## 5. Типовые вопросы на собеседовании (Interview Q&A)

**1. Как в Flux CD архитектурно разделена работа между Source Controller и Kustomize Controller?**
*Ответ:* Flux следует микросервисному паттерну. `Source Controller` занимается исключительно общением с внешним миром (Git, Helm-репозитории, S3): качает исходники, проверяет PGP-подписи коммитов, упаковывает их в тарбол и раздаёт внутри кластера. `Kustomize Controller` (или `Helm Controller`) не знает ничего про Git — он берёт готовый артефакт от Source Controller, рендерит финальные YAML-манифесты и применяет их в k8s API. Это улучшает безопасность (меньше прав у каждого отдельного контроллера) и масштабируемость.

**2. Зачем в Flux нужны два разных ресурса — `GitRepository` и `Kustomization` — если в ArgoCD для того же самого достаточно одного `Application`?**
*Ответ:* Это разделение ответственности. `GitRepository` описывает только "откуда брать байты" (URL, ветка, интервал опроса) и ничего не знает про то, что с этими манифестами делать. `Kustomization` (или `HelmRelease`) описывает "что применить и куда" — путь внутри репозитория, целевой namespace, политику prune. Один `GitRepository` может переиспользоваться несколькими `Kustomization`, указывающими на разные подпапки одного и того же репозитория — например, отдельно "инфраструктура" и отдельно "приложения" из одного моно-репо.

**3. Как Flux Image Automation Controller решает задачу "выкатить новую версию образа без ручного git commit разработчиком в репозиторий манифестов"?**
*Ответ:* `ImageRepository` следит за registry и находит новые теги образа. `ImagePolicy` определяет, какой из найденных тегов считать "новее" (например, по semver-диапазону). Когда находится подходящий новый тег, `ImageUpdateAutomation` сам делает git-коммит в репозиторий с манифестами, заменяя старый тег на новый прямо в YAML. Kustomize Controller подхватывает этот коммит через обычный Reconciliation Loop — разработчику не нужно вручную трогать репозиторий с манифестами.

**4. Команда выбирает между ArgoCD и Flux для нового проекта. У них нет отдельной команды платформенной инженерии, а разработчики хотят сами смотреть статус деплоя визуально. Что предпочесть и почему?**
*Ответ:* В этом случае ArgoCD обычно предпочтительнее — у него есть готовый веб-UI из коробки, где разработчик без специальных навыков CLI видит дерево ресурсов, статус `OutOfSync`/`Healthy` и diff между Git и кластером. У Flux нет встроенного UI (нужно отдельно ставить и поддерживать Weave GitOps или писать дашборды поверх Prometheus-метрик Flux), что добавляет операционную нагрузку без выделенной платформенной команды. Flux, в свою очередь, более уместен, когда команда уже привыкла работать через CLI/декларативные CRD и ценит минималистичную, полностью Unix-way архитектуру без единой точки отказа в виде UI-сервера.
