# Упражнения — CRD и Operators

Стенд: 🐳 Tier 1 — kind

```bash
kind create cluster --name operators-lab
```

## 01 — CRD без Operator: схема есть, поведения нет

**Задача:** Применить CRD `Website` и создать CR, наглядно убедиться, что "ничего не происходит".

```bash
kubectl apply -f ../02_examples/website-crd.yaml
kubectl apply -f ../02_examples/website-cr.yaml

kubectl get websites          # объект есть
kubectl get ws                # shortName тоже работает
kubectl get deployments        # TODO: убедиться что Deployment для сайта НЕ появился

# Это и есть суть §1 из теории: CRD — только схема, реального поведения нет
```

## 02 — additionalPrinterColumns

**Задача:** Убедиться, что `kubectl get websites` показывает колонки `Domain`/`Phase` из `additionalPrinterColumns`, а не просто `NAME`/`AGE` как для произвольного ресурса.

```bash
kubectl get websites -o wide
# TODO: сравни вывод с обычным `kubectl get configmaps` — почему у Website
# в выводе появились кастомные колонки Domain/Phase?
```

## 03 — Симуляция Reconcile (без написания настоящего оператора)

**Задача:** Bash-скриптом эмулировать простейший reconcile loop: следить за CR и создавать/удалять Deployment по его `spec`.

```bash
# TODO: написать скрипт, который в цикле (или через `kubectl get --watch`)
# читает spec.replicas у Website и делает `kubectl scale` для соответствующего
# Deployment, если он уже отличается — это тот же паттерн, что у настоящего
# оператора, только без Informer/client-go, реализованный поверх kubectl.
```
