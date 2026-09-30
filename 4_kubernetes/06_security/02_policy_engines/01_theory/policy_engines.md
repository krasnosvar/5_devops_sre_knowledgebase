# Policy Engines: OPA Gatekeeper vs Kyverno

## Содержание
1. [Зачем нужен Admission Controller Policy Engine](#1-зачем-нужен-admission-controller-policy-engine)
2. [OPA Gatekeeper: Rego, ConstraintTemplate + Constraint](#2-opa-gatekeeper-rego-constrainttemplate--constraint)
3. [Kyverno: нативный YAML, Validate vs Mutate](#3-kyverno-нативный-yaml-validate-vs-mutate)
4. [failurePolicy: что если сам движок упадёт](#4-failurepolicy-что-если-сам-движок-упадёт)
5. [Типовые вопросы на собеседовании (Interview Q&A)](#5-типовые-вопросы-на-собеседовании-interview-qa)

> Встроенные примитивы безопасности k8s (RBAC, SecurityContext, PSA) — в [`../01_core/`](../../01_core/).
> Механика Admission-фазы в целом — в [`../../../01_architecture/`](../../../01_architecture/) §3.

---

## 1. Зачем нужен Admission Controller Policy Engine

Pod Security Admission (см. [`../01_core/`](../../01_core/) §4) проверяет только безопасность самого пода (root/non-root, capabilities). А как запретить деплоить `Ingress` без TLS-сертификата, образы с тегом `:latest` или Deployment без указания `team`-лейбла? Для произвольных корпоративных правил нужны Admission Controller Webhooks — синхронные HTTPS-вызовы, которые API-сервер делает на этапе Admission (см. [`../../../01_architecture/`](../../../01_architecture/) §3), ДО сохранения ресурса в etcd.

Два конкурирующих движка реализуют эту идею:
- **OPA Gatekeeper** — универсальный движок политик (используется не только в k8s, но и в CI, Envoy), стандарт CNCF.
- **Kyverno** — создан исключительно для Kubernetes, декларативный, cloud-native.

## 2. OPA Gatekeeper: Rego, ConstraintTemplate + Constraint

Политики пишутся на языке **Rego** — мощном, но сложном декларативном DSL, требующем отдельного изучения:

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sdisallowedtags
spec:
  crd:
    spec:
      names: {kind: K8sDisallowedTags}
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sdisallowedtags
        violation[{"msg": msg}] {
          image := input.review.object.spec.containers[_].image
          endswith(image, ":latest")
          msg := "Тег :latest запрещён"
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sDisallowedTags
metadata:
  name: no-latest-tag
spec:
  match:
    kinds: [{apiGroups: [""], kinds: ["Pod"]}]
```

Двухуровневая архитектура: `ConstraintTemplate` — переиспользуемая логика правила (Rego), `Constraint` — конкретное применение шаблона к набору ресурсов. Gatekeeper — стандарт CNCF, очень мощный, но порог входа высокий именно из-за Rego.

## 3. Kyverno: нативный YAML, Validate vs Mutate

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-latest-tag
spec:
  validationFailureAction: Enforce
  rules:
    - name: require-image-tag
      match:
        resources:
          kinds: [Pod]
      validate:
        message: "Тег :latest запрещён"
        pattern:
          spec:
            containers:
              - image: "!*:latest"
```

Политики пишутся на **обычном YAML** — без отдельного языка. Kyverno умеет не только блокировать (`validate`), но и **мутировать** (`mutate`) манифесты на лету — например, автоматически добавить дефолтные `resources.limits`, если разработчик забыл их указать, ещё до сохранения объекта в etcd.

## 4. failurePolicy: что если сам движок упадёт

Admission Webhook — критический компонент в цепочке создания любого ресурса. Что произойдёт, если Kyverno/OPA упадёт (OOM, сетевая недоступность) в момент, когда кто-то делает `kubectl apply`? Ответ зависит от `failurePolicy` в `ValidatingWebhookConfiguration`:
- **`Fail`** (Strict mode) — API-сервер, не получив ответа от вебхука за 10-30 секунд, запретит создание **любого** ресурса, попадающего под это правило. Кластер может оказаться частично парализован.
- **`Ignore`** (Fail-open) — API-сервер проигнорирует падение политик и пропустит манифест. Безопасность нарушена, но доступность сохранена.

На практике SRE держат сам движок (Kyverno/OPA) в нескольких репликах именно для того, чтобы вопрос `Fail` vs `Ignore` вообще редко всплывал на практике.

---

## 5. Типовые вопросы на собеседовании (Interview Q&A)

**1. Как OPA Gatekeeper перехватывает создание ресурсов (например, запрет `:latest`)? Какая архитектура k8s задействована?**
*Ответ:* OPA Gatekeeper использует Dynamic Admission Control (Validating Admission Webhook). Когда вы делаете `kubectl apply`, запрос проходит аутентификацию и авторизацию (RBAC) в API-сервере. ДО сохранения манифеста в etcd (на фазе Admission) API-сервер делает синхронный HTTPS-вызов на вебхук Gatekeeper'а. Gatekeeper прогоняет пришедший JSON через правила на Rego и возвращает вердикт: `Allow` или `Deny` с сообщением.

**2. В чём идеологическая и синтаксическая разница между написанием политик в OPA Gatekeeper и Kyverno?**
*Ответ:* OPA — универсальный движок (используется и в k8s, и в CI, и в Envoy), политики пишутся на DSL-языке Rego — мощном, но сложном для инженеров, привыкших к YAML. Kyverno создавался исключительно для Kubernetes: политики пишутся на нативном YAML — берёте кусок манифеста, ставите шаблон вроде `image: "!*:latest"` и говорите "запретить". Порог входа в Kyverno на порядок ниже.

**3. Что произойдёт, если Admission Webhook (например, Kyverno), проверяющий все манифесты, упадёт (OOM или недоступен по сети)? Сможете ли вы создавать поды?**
*Ответ:* Зависит от `failurePolicy` в `ValidatingWebhookConfiguration`. Если `Fail` (Strict) — API-сервер, не получив ответа от вебхука, запретит создание любого ресурса, подпадающего под правило — кластер окажется частично парализован. Если `Ignore` (Fail-open) — API-сервер пропустит манифест мимо проверки: безопасность нарушена, но доступность сохранена. SRE настраивают отказоустойчивость самого Kyverno/OPA (несколько реплик), чтобы этот выбор редко вставал на практике.

**4. Чем `MutatingAdmissionWebhook` в Kyverno отличается от `ValidatingAdmissionWebhook`, и как Kyverno использует это для исправления манифестов?**
*Ответ:* Validating-вебхук только проверяет манифест и говорит `Allow`/`Deny`, ничего не меняя. Mutating-вебхук может **изменить** манифест "на лету" до его сохранения. Например, разработчик деплоит под без `resources.limits`. Kyverno через Mutating-правило перехватывает манифест, дописывает туда дефолтные `cpu: 100m, memory: 128Mi` и возвращает исправленный YAML обратно API-серверу — разработчику ничего не нужно исправлять руками, кластер сам приводит манифесты к корпоративному стандарту.
