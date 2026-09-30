# Упражнения — Helm

Стенд: 🐳 Tier 1 — kind или k3d кластер

## 01 — Написать chart с нуля

**Задача:** Создать Helm chart для nginx с параметризованным replicas, image, port.

```bash
# Создать скелет
helm create myapp
# Удалить лишнее из templates/
rm -rf myapp/templates/tests/ myapp/templates/hpa.yaml myapp/templates/serviceaccount.yaml

# TODO: упростить deployment.yaml, service.yaml
# В values.yaml оставить: replicaCount, image.tag, service.port

# Проверить рендер
helm template myapp ./myapp

# Установить
helm install myapp ./myapp --set replicaCount=2

# Проверить
kubectl get pods
helm list
```

## 02 — Обновить и откатить релиз

```bash
# Обновить image tag
helm upgrade myapp ./myapp --set image.tag=1.25

# Посмотреть историю
helm history myapp

# Откатить к предыдущей версии
helm rollback myapp 1

# Убедиться что откат применился
kubectl describe deployment myapp | grep Image
```

## 03 — Helm из публичного registry

```bash
# Установить Bitnami PostgreSQL
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Показать все доступные values
helm show values bitnami/postgresql | head -50

# Установить с кастомными values
helm install my-postgres bitnami/postgresql \
  --set auth.postgresPassword=secret123 \
  --set primary.persistence.size=1Gi \
  --create-namespace -n database \
  --wait

# Проверить
kubectl get pods -n database
helm list -n database

# Подключиться к PostgreSQL
kubectl exec -it my-postgres-postgresql-0 -n database -- \
  psql -U postgres -c "\l"
```

## 04 — helm diff (требует плагин)

```bash
# Установить helm-diff
helm plugin install https://github.com/databus23/helm-diff

# Посмотреть что изменится ПЕРЕД обновлением
helm diff upgrade my-postgres bitnami/postgresql \
  --set auth.postgresPassword=newsecret \
  -n database
```
