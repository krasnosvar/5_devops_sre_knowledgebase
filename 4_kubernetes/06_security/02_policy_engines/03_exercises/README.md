# Упражнения — Policy Engines (Kyverno / OPA Gatekeeper)

Стенд: 🐳 Tier 1 — kind

Ответы: [04_exercises_answers/policy-engines-answers.md](../04_exercises_answers/policy-engines-answers.md).

```bash
kind create cluster --name policy-lab
```

## 01 — Kyverno: запретить :latest

**Задача:** Поставить Kyverno, применить `disallow-latest-tag`, убедиться
что под с `:latest` отклоняется.

```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm install kyverno kyverno/kyverno -n kyverno --create-namespace --wait

kubectl apply -f ../02_examples/kyverno-policy.yaml

# Должно быть отклонено:
kubectl run bad-pod --image=nginx:latest
# Проверить сообщение об ошибке — совпадает ли с message из ClusterPolicy?

# Должно пройти:
kubectl run good-pod --image=nginx:1.25.3
```

## 02 — Kyverno: mutate — дефолтные лимиты

**Задача:** Задеплоить под без `resources`, убедиться что Kyverno сам
подставил дефолтные лимиты (политика `add-default-resources`).

```bash
kubectl run no-limits-pod --image=nginx:1.25.3 --dry-run=server -o yaml | grep -A3 ' resources'
# Сравнить с тем, что реально сохранится (без --dry-run). Объяснить,
# почему лимиты видны уже в server dry-run и откуда взялись requests.
```

## 03 — OPA Gatekeeper: то же правило, на Rego

**Задача:** Поставить Gatekeeper, применить `opa-constraint.yaml`,
сравнить с поведением Kyverno из упражнения 01 — сообщение об ошибке
и `failurePolicy` по умолчанию. Чтобы увидеть именно ответ Gatekeeper,
перед этим удалите политики Kyverno (или весь Kyverno).

```bash
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm install gatekeeper gatekeeper/gatekeeper -n gatekeeper-system --create-namespace --wait
kubectl apply -f ../02_examples/opa-constraint.yaml

kubectl run bad-pod-2 --image=nginx:latest
# Сравнить формулировку ошибки с Kyverno — какая понятнее для разработчика?
```

## 04 — failurePolicy: Fail vs Ignore

**Задача:** Сымитировать недоступность Kyverno и посмотреть, что
произойдёт с созданием подов при `failurePolicy: Fail` (дефолт Kyverno)
и `Ignore`.

Простое `kubectl scale --replicas=0` аварию не воспроизводит: при
штатной остановке Kyverno сам удаляет свои вебхуки, и поды начинают
создаваться без проверки. Поэтому недоступность имитируется поломкой
Service `kyverno-svc` (лишний ключ в selector) с перезапуском admission
controller (в chart v3+ Deployment называется
`kyverno-admission-controller`, а не `kyverno`).

```bash
kubectl -n kyverno patch svc kyverno-svc --type=merge \
  -p '{"spec":{"selector":{"outage":"simulated"}}}'
kubectl -n kyverno rollout restart deployment/kyverno-admission-controller
kubectl -n kyverno rollout status deployment/kyverno-admission-controller

# С failurePolicy: Fail — создание пода должно упасть
kubectl run test-pod --image=nginx:1.25.3

# Найти, как перевести политики на failurePolicy: Ignore, и повторить
# аварию — теперь под должен создаться. Подсказка: править
# ValidatingWebhookConfiguration руками бесполезно, и во время аварии
# Kyverno не даст изменить и сами политики.
kubectl get validatingwebhookconfigurations
```
