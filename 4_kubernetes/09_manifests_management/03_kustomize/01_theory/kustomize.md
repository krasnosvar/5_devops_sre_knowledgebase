# Kustomize: Патчи и Генераторы без шаблонов

## Содержание
1. [Bases и Overlays](#1-bases-и-overlays)
2. [ConfigMapGenerator и автоматический Rolling Update](#2-configmapgenerator-и-автоматический-rolling-update)
3. [Strategic Merge Patch vs JSON Patch](#3-strategic-merge-patch-vs-json-patch)
4. [Удаление ресурса из base: $patch: delete](#4-удаление-ресурса-из-base-patch-delete)
5. [Связка с Helm (блок helmCharts)](#5-связка-с-helm-блок-helmcharts)
6. [Типовые вопросы на собеседовании (Interview Q&A)](#6-типовые-вопросы-на-собеседовании-interview-qa)

> Общая теория работы с манифестами (labels, apply, SSA) — в [`../../01_theory/`](../../01_theory/).
> Сравнение с Helm — в [`../../02_helm/`](../../02_helm/).

---

## 1. Bases и Overlays

**Kustomize** встроен в `kubectl` (`kubectl apply -k`). В отличие от Helm, в нём нет шаблонизации (`{{ if }}`) — это инструмент "структурной манипуляции", который накладывает патчи на чистый YAML.

Структура: папка `base/` содержит универсальные манифесты, папки `overlays/dev/`, `overlays/prod/` — патчи поверх base для конкретного окружения.

```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml

# overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: myapp-prod
resources:
  - ../../base
patches:
  - path: patch-replicas.yaml
    target:
      kind: Deployment
      name: myapp
```
```bash
kubectl kustomize overlays/prod/   # посмотреть итоговый YAML
kubectl apply -k overlays/prod/    # применить в кластер
```

## 2. ConfigMapGenerator и автоматический Rolling Update

Главная фича Kustomize. Вместо того чтобы прописывать ConfigMap руками, вы описываете генератор:

```yaml
configMapGenerator:
  - name: myapp-config
    literals:
      - LOG_LEVEL=info
```

Kustomize создаёт ConfigMap и добавляет к его имени SHA-хэш содержимого (`myapp-config-8f92bd`). При изменении конфига хэш меняется → имя ConfigMap меняется → ссылка на него в Deployment (которую Kustomize тоже переписывает автоматически) меняется → k8s видит изменение манифеста Deployment и сам запускает **Rolling Update**. Это решает классическую проблему "ConfigMap обновился, а поды не подхватили изменения" без ручных чек-сумм в аннотациях (как приходится делать в Helm).

## 3. Strategic Merge Patch vs JSON Patch

- **Strategic Merge Patch** — понимает структуру Kubernetes. Пишете обычный кусок YAML с `metadata.name`, Kustomize сам находит нужный контейнер по имени и сливает настройки:
  ```yaml
  apiVersion: apps/v1
  kind: Deployment
  metadata: {name: myapp}
  spec:
    template:
      spec:
        containers:
          - name: myapp
            image: myapp:v1.4.2
  ```
- **JSON Patch (RFC 6902)** — хирургическое вмешательство, не знающее ничего про структуру k8s. Нужен там, где Strategic Merge неудобен — например, для позиционных массивов без имён (аргументы запуска):
  ```yaml
  patches:
    - target: {kind: Deployment, name: myapp}
      patch: |-
        - op: add
          path: /spec/template/spec/containers/0/args
          value: ["--verbose=false"]
  ```

## 4. Удаление ресурса из base: $patch: delete

Иногда ресурс из `base` не нужен в конкретном оверлее (например, Ingress не нужен в dev, где используется port-forward):

```yaml
$patch: delete
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
```

**Критично**: `$patch: delete` должен быть **верхнеуровневым** ключом документа, рядом с `apiVersion`/`kind` — если вложить его внутрь `metadata`, Kustomize молча проигнорирует директиву, и ресурс останется в выводе без единой ошибки или предупреждения. Это реальная ловушка, которую легко не заметить: собранный YAML выглядит нормально, ресурс просто никуда не девается.

## 5. Связка с Helm (блок helmCharts)

Helm и Kustomize не исключают, а дополняют друг друга. Частый случай: вы берёте публичный Helm-чарт, но нужно добавить то, чего нет в его `values.yaml` (сайдкар-контейнер, кастомный патч). Kustomize умеет скачать чарт, отрендерить его локально в сырой YAML через `helmCharts`, и наложить сверху свои патчи — перед отправкой в кластер:

```yaml
helmCharts:
  - name: myapp
    repo: https://charts.example.com
    version: 1.2.0
    releaseName: myapp
    valuesFile: values.yaml
patches:
  - path: add-sidecar.yaml
```

---

## 6. Типовые вопросы на собеседовании (Interview Q&A)

**1. В чём фундаментальная разница между Helm и Kustomize? Когда выбрать один, а когда другой?**
*Ответ:* Helm — текстовый шаблонизатор с пакетным менеджером. Идеален для распространения публичного софта "коробочного" типа (установка БД, Ingress, мониторинга), где пользователю нужно просто поменять пару переменных в `values.yaml`. Kustomize — инструмент наложения патчей без шаблонов (Template-free). Идеален для внутренних CI/CD пайплайнов микросервисов компании, где нужно взять один базовый манифест и слегка модифицировать его для сред Dev, Stage и Prod, не разводя месиво из `{{ if }}`.

**2. Разработчик обновил файл конфига, примонтированный в под через ConfigMap. Файл в кластере обновился, но приложение не подхватило изменения. Как в Kustomize заставить поды перезапуститься автоматически?**
*Ответ:* В ванильном k8s поды читают ConfigMap только при старте. Нужно, чтобы изменился сам манифест Deployment. `configMapGenerator` в Kustomize автоматически добавляет хэш содержимого конфига в имя создаваемого ConfigMap и обновляет ссылку на него в Deployment — при изменении конфига хэш меняется, манифест Deployment меняется, и k8s сам инициирует Rolling Update. Ручных чек-сумм в аннотациях, как в Helm, здесь не требуется.

**3. Как в Kustomize удалить ресурс (например, Ingress), который был определён в base, чтобы он не создавался в конкретном оверлее?**
*Ответ:* Директива `$patch: delete`. Создаётся файл с минимальной структурой ресурса (`apiVersion`, `kind`, `metadata.name` — ровно столько, чтобы Kustomize нашёл нужный объект по `kind`+`name`), и `$patch: delete` указывается **на верхнем уровне документа**, рядом с `apiVersion`/`kind` — не внутри `metadata`. При вложении внутрь `metadata` директива будет молча проигнорирована без единой ошибки, и ресурс останется в итоговом выводе.

**4. В чём разница между `Strategic Merge Patch` и `JSON Patch (RFC 6902)` в Kustomize?**
*Ответ:* `Strategic Merge Patch` понимает структуру Kubernetes: пишете обычный кусок YAML, и Kustomize сам находит контейнер по ключу `name` и сливает настройки. `JSON Patch` — хирургическое вмешательство, которое ничего не знает про k8s, используется для изменения простых позиционных массивов (например, аргументов запуска), где нет имён для strategic-мержа. Синтаксис — явные операции: `- op: replace, path: /spec/containers/0/args/1, value: "start"`.
