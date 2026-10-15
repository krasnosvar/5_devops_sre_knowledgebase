# Ответы — Policy Engines (Kyverno / OPA Gatekeeper)

Команды выполняются из каталога
`4_kubernetes/06_security/02_policy_engines/`. Проверено на Kyverno
1.19 (chart 3.9) и Gatekeeper 3.23; в других версиях текст сообщений
может немного отличаться. Манифест к упражнению 04 —
[kyverno-policy-ignore.yaml](./kyverno-policy-ignore.yaml).

## Упражнение 01 — Kyverno: запретить :latest

```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm install kyverno kyverno/kyverno -n kyverno --create-namespace --wait
kubectl get deployments -n kyverno
kubectl apply -f 02_examples/kyverno-policy.yaml
kubectl wait --for=condition=Ready clusterpolicy --all --timeout=60s
kubectl run bad-pod --image=nginx:latest
kubectl run good-pod --image=nginx:1.25.3
```

Ожидаемый вывод (примерно так):

```text
NAME                            READY   UP-TO-DATE   AVAILABLE   AGE
kyverno-admission-controller    1/1     1            1           70s
kyverno-background-controller   1/1     1            1           70s
kyverno-cleanup-controller      1/1     1            1           70s
kyverno-reports-controller      1/1     1            1           70s
Warning: kyverno.io/v1 ClusterPolicy is deprecated ...
clusterpolicy.kyverno.io/disallow-latest-tag created
clusterpolicy.kyverno.io/add-default-resources created
...
Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:

resource Pod/default/bad-pod was blocked due to the following policies

disallow-latest-tag:
  require-image-tag: 'validation error: Тег :latest запрещён, укажите конкретную
  версию образа. rule require-image-tag failed at path /spec/containers/0/image/'
pod/good-pod created
```

Почему так: сообщение совпадает с `validate.message` политики, Kyverno
дописывает к нему имя политики, правила и путь к полю. Имя вебхука
`validate.kyverno.svc-fail` говорит, что он зарегистрирован с
`failurePolicy: Fail`. Подвох шаблона `!*:latest`: образ без тега
(`nginx`) тоже означает latest, но под шаблон не попадает и пройдёт.

## Упражнение 02 — Kyverno: mutate — дефолтные лимиты

```bash
kubectl run no-limits-pod --image=nginx:1.25.3 --dry-run=server -o yaml \
  | grep -A3 ' resources'
kubectl run no-limits-pod --image=nginx:1.25.3
kubectl get pod no-limits-pod \
  -o jsonpath='{.spec.containers[0].resources}{"\n"}'
```

Ожидаемый вывод (примерно так):

```text
    resources:
      limits:
        cpu: 200m
        memory: 256Mi
pod/no-limits-pod created
{"limits":{"cpu":"200m","memory":"256Mi"},"requests":{"cpu":"200m","memory":"256Mi"}}
```

Почему так: `--dry-run=server` проходит все стадии admission, включая
mutating-вебхуки (у Kyverno `sideEffects: None`, поэтому dry-run
поддерживается), просто не сохраняет объект — лимиты видны уже там.
`requests` никто явно не задавал: если у контейнера есть только
`limits`, API-сервер при defaulting копирует их в `requests`, и под
становится Guaranteed.

## Упражнение 03 — OPA Gatekeeper: то же правило, на Rego

```bash
kubectl delete clusterpolicy disallow-latest-tag add-default-resources
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm install gatekeeper gatekeeper/gatekeeper -n gatekeeper-system \
  --create-namespace --wait
kubectl apply -f 02_examples/opa-constraint.yaml
kubectl wait --for condition=established \
  crd/k8sdisallowedtags.constraints.gatekeeper.sh --timeout=60s
kubectl apply -f 02_examples/opa-constraint.yaml
kubectl run bad-pod-2 --image=nginx:latest
kubectl get validatingwebhookconfiguration \
  gatekeeper-validating-webhook-configuration \
  -o jsonpath='{range .webhooks[*]}{.name} {.failurePolicy}{"\n"}{end}'
```

Ожидаемый вывод (примерно так):

```text
constrainttemplate.templates.gatekeeper.sh/k8sdisallowedtags created
error: resource mapping not found for name: "no-latest-tag" ...
no matches for kind "K8sDisallowedTags" in version "constraints.gatekeeper.sh/v1beta1"
customresourcedefinition.apiextensions.k8s.io/k8sdisallowedtags.constraints.gatekeeper.sh condition met
constrainttemplate.templates.gatekeeper.sh/k8sdisallowedtags unchanged
k8sdisallowedtags.constraints.gatekeeper.sh/no-latest-tag created
Error from server (Forbidden): admission webhook "validation.gatekeeper.sh"
denied the request: [no-latest-tag] Тег :latest запрещён в контейнере bad-pod-2
validation.gatekeeper.sh Ignore
check-ignore-label.gatekeeper.sh Fail
```

Почему так: CRD `K8sDisallowedTags` Gatekeeper создаёт из
ConstraintTemplate асинхронно, поэтому первый `apply` падает на
Constraint — нужно дождаться CRD и применить ещё раз. Если сразу после
этого под с `:latest` прошёл, подождите несколько секунд: Constraint
тоже вступает в силу не мгновенно. Сообщение Gatekeeper короче (только
имя Constraint и текст из Rego), а его основной вебхук по умолчанию
`Ignore` — в отличие от `Fail` у Kyverno.

## Упражнение 04 — failurePolicy: Fail vs Ignore

Gatekeeper из упражнения 03 удалите (`helm uninstall gatekeeper -n
gatekeeper-system`), Kyverno и его политики из
[02_examples/kyverno-policy.yaml](../02_examples/kyverno-policy.yaml)
должны быть применены.

Шаг 1 — авария при `Fail`:

```bash
kubectl -n kyverno patch svc kyverno-svc --type=merge \
  -p '{"spec":{"selector":{"outage":"simulated"}}}'
kubectl -n kyverno rollout restart deployment/kyverno-admission-controller
kubectl -n kyverno rollout status deployment/kyverno-admission-controller
kubectl get validatingwebhookconfiguration kyverno-resource-validating-webhook-cfg \
  -o jsonpath='{range .webhooks[*]}{.name} {.failurePolicy}{"\n"}{end}'
kubectl run test-pod --image=nginx:1.25.3
kubectl apply -f 04_exercises_answers/kyverno-policy-ignore.yaml
```

Ожидаемый вывод (примерно так):

```text
service/kyverno-svc patched
deployment.apps/kyverno-admission-controller restarted
deployment "kyverno-admission-controller" successfully rolled out
validate.kyverno.svc-fail Fail
Error from server (InternalError): Internal error occurred: failed calling
webhook "mutate.kyverno.svc-fail": failed to call webhook: Post
"https://kyverno-svc.kyverno.svc:443/mutate/fail?timeout=10s": dial tcp
10.96.168.105:443: connect: connection refused
Error from server (InternalError): ... failed calling webhook
"mutate-policy.kyverno.svc": ... connection refused
```

Шаг 2 — починить, перевести политики на `Ignore`, повторить аварию:

```bash
kubectl -n kyverno patch svc kyverno-svc --type=json \
  -p '[{"op":"remove","path":"/spec/selector/outage"}]'
kubectl get endpointslices -n kyverno -l kubernetes.io/service-name=kyverno-svc
kubectl apply -f 04_exercises_answers/kyverno-policy-ignore.yaml
kubectl get validatingwebhookconfiguration kyverno-resource-validating-webhook-cfg \
  -o jsonpath='{range .webhooks[*]}{.name} {.failurePolicy}{"\n"}{end}'
kubectl -n kyverno patch svc kyverno-svc --type=merge \
  -p '{"spec":{"selector":{"outage":"simulated"}}}'
kubectl -n kyverno rollout restart deployment/kyverno-admission-controller
kubectl -n kyverno rollout status deployment/kyverno-admission-controller
kubectl run test-pod --image=nginx:1.25.3
kubectl run bad-pod --image=nginx:latest
```

Ожидаемый вывод (примерно так):

```text
service/kyverno-svc patched
NAME                ADDRESSTYPE   PORTS   ENDPOINTS     AGE
kyverno-svc-znbtq   IPv4          ...     10.244.1.12   20m
clusterpolicy.kyverno.io/disallow-latest-tag configured
clusterpolicy.kyverno.io/add-default-resources configured
validate.kyverno.svc-ignore Ignore
service/kyverno-svc patched
deployment.apps/kyverno-admission-controller restarted
deployment "kyverno-admission-controller" successfully rolled out
pod/test-pod created
pod/bad-pod created
```

Если `validate.kyverno.svc-ignore` появился не сразу — повторите
`kubectl get validatingwebhookconfiguration` через несколько секунд:
Kyverno пересобирает вебхуки асинхронно.

Уборка:

```bash
kubectl -n kyverno patch svc kyverno-svc --type=json \
  -p '[{"op":"remove","path":"/spec/selector/outage"}]'
kubectl delete pod test-pod bad-pod
```

Почему так: при `Fail` API-сервер отказывает в любом запросе, который
должен пройти через недоступный вебхук. В шаге 1 не удаётся даже
применить политику с `Ignore` — сами политики Kyverno тоже проходят
через его вебхук (`mutate-policy.kyverno.svc`), поэтому `failurePolicy`
нужно выбирать заранее. Ручная правка `failurePolicy` в
`ValidatingWebhookConfiguration` не помогает: работающий Kyverno сразу
возвращает её обратно. При `Ignore` кластер доступен, но проверка не
выполняется: `nginx:latest` тоже прошёл — это и есть цена fail-open.
Перезапуск admission controller нужен, чтобы оборвать уже открытые
соединения API-сервера к старому поду; без него вебхук ещё какое-то
время может отвечать.
