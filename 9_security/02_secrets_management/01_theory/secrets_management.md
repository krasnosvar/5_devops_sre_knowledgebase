# Secrets Management

## Почему k8s Secret небезопасен по умолчанию

k8s Secret — это base64 encoded данные в etcd.
Base64 — не шифрование. Любой у кого есть доступ к etcd читает все секреты.

```bash
# "секрет" доступен как plain text
kubectl get secret mysecret -o jsonpath='{.data.password}' | base64 -d

# в etcd (если есть доступ к etcd)
ETCDCTL_API=3 etcdctl get /registry/secrets/default/mysecret
# вернёт plain text данные
```

**Что делать:**
1. Шифровать etcd at rest (EncryptionConfiguration)
2. Использовать внешний secret manager (Vault, AWS Secrets Manager)
3. Ограничить RBAC доступ к Secrets (least privilege)

## HashiCorp Vault / OpenBao

Vault — централизованное хранилище секретов с:
- динамическими секретами (генерируются по запросу, автоматически ротируются)
- политиками доступа (кто может читать что)
- audit log (кто когда что читал)
- lease (секрет живёт ограниченное время)

```bash
# логин в Vault
vault login -method=kubernetes role=myapp

# читать секрет
vault kv get secret/myapp/database
vault kv get -field=password secret/myapp/database

# динамический секрет PostgreSQL (генерируется при каждом запросе)
vault read database/creds/myapp-role
# вернёт: username=v-myapp-AbCd, password=<random>, lease=1h
# через 1 час credentials автоматически отзываются

# статический секрет (обычный KV)
vault kv put secret/myapp/config \
  api_key="key123" \
  db_password="securepassword"
```

## External Secrets Operator — мост Vault → k8s Secret

ESO синхронизирует секреты из внешних систем (Vault, AWS SM, GCP SM) в k8s Secret.
Ротация: при изменении в Vault → k8s Secret обновляется автоматически.

```yaml
# SecretStore — подключение к Vault
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "http://vault.vault.svc.cluster.local:8200"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "external-secrets"

---
# ExternalSecret — какой секрет создать в k8s
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: myapp-db-secret
  namespace: production
spec:
  refreshInterval: 1h          # как часто синхронизировать
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: myapp-db-secret      # имя k8s Secret который будет создан
    creationPolicy: Owner
  data:
    - secretKey: password      # ключ в k8s Secret
      remoteRef:
        key: secret/myapp/database  # путь в Vault
        property: password          # поле
```

## Sealed Secrets — для GitOps

SealedSecret позволяет хранить зашифрованные секреты в Git.
Только контроллер в кластере может расшифровать.

```bash
# установить kubeseal CLI
brew install kubeseal

# получить публичный ключ кластера
kubeseal --fetch-cert > pub-cert.pem

# создать SealedSecret из обычного Secret
kubectl create secret generic mysecret \
  --dry-run=client \
  --from-literal=password=mysecretpassword \
  -o yaml | kubeseal --cert pub-cert.pem -o yaml > sealed-secret.yaml

# закоммитить sealed-secret.yaml в Git (безопасно)
git add sealed-secret.yaml && git commit -m "Add db sealed secret"

# ArgoCD применит SealedSecret → контроллер расшифрует → создаст k8s Secret
```

## AWS Secrets Manager + IRSA (для EKS)

```yaml
# Pod использует IAM роль через ServiceAccount (без credentials в коде)
apiVersion: v1
kind: ServiceAccount
metadata:
  name: myapp
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/myapp-role

---
# ExternalSecret с AWS Secrets Manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: eu-central-1
      auth:
        jwt:
          serviceAccountRef:
            name: myapp   # использует IRSA автоматически
```

## Что никогда не делать

```bash
# НИКОГДА не коммитить secrets в Git (даже в .gitignore файлах)
git log --all --full-history -- '*.env'   # проверить историю

# НИКОГДА не передавать секреты через ENV в Dockerfile
ENV DB_PASSWORD=mysecret123   # запечён в образ, виден в docker inspect

# НИКОГДА не логировать секреты
logger.info(f"Connecting with password={password}")

# НИКОГДА не хранить в конфигмапах
apiVersion: v1
kind: ConfigMap
data:
  password: "mysecret"   # ConfigMap не зашифрован
```
