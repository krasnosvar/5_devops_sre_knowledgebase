# Упражнения — Policy Engines (Kyverno / OPA Gatekeeper)

Стенд: 🐳 Tier 1 — kind

```bash
kind create cluster --name policy-lab
```

## 01 — Kyverno: запретить :latest

**Задача:** Поставить Kyverno, применить `disallow-latest-tag`, убедиться что под с `:latest` отклоняется.

```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm install kyverno kyverno/kyverno -n kyverno --create-namespace

kubectl apply -f ../02_examples/kyverno-policy.yaml

# Должно быть отклонено:
kubectl run bad-pod --image=nginx:latest
# TODO: проверить сообщение об ошибке — совпадает ли с message из ClusterPolicy?

# Должно пройти:
kubectl run good-pod --image=nginx:1.25.3
```

## 02 — Kyverno: mutate — дефолтные лимиты

**Задача:** Задеплоить под без `resources`, убедиться что Kyverno сам подставил дефолтные лимиты (политика `add-default-resources`).

```bash
kubectl run no-limits-pod --image=nginx:1.25.3 --dry-run=server -o yaml | grep -A3 resources
# TODO: сравни с тем, что реально применится (без --dry-run) — лимиты должны появиться
```

## 03 — OPA Gatekeeper: то же правило, на Rego

**Задача:** Поставить Gatekeeper, применить `opa-constraint.yaml`, сравнить с поведением Kyverno из упражнения 01 — сообщение об ошибке и время реакции.

```bash
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml
kubectl apply -f ../02_examples/opa-constraint.yaml

kubectl run bad-pod-2 --image=nginx:latest
# TODO: сравни формулировку ошибки с Kyverno — какая понятнее для разработчика?
```

## 04 — failurePolicy: Fail vs Ignore

**Задача:** Смасштабировать Kyverno до 0 реплик и посмотреть, что произойдёт с `kubectl apply` при разных `failurePolicy`.

```bash
kubectl scale deployment kyverno -n kyverno --replicas=0

# С failurePolicy: Fail (дефолт у Kyverno) — apply должен зависнуть/упасть
kubectl run test-pod --image=nginx:1.25.3

# TODO: найти ValidatingWebhookConfiguration и поменять failurePolicy на Ignore,
# повторить попытку — теперь apply должен пройти, несмотря на выключенный Kyverno
kubectl get validatingwebhookconfigurations
```
