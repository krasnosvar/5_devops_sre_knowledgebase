# Secrets Management — шпаргалка

Подробности и объяснения — в
[01_theory/secrets_management.md](./01_theory/secrets_management.md).
⚠️ — опасная команда или частая ловушка.

## Когда что использовать

| Ситуация | Инструмент |
| :--- | :--- |
| Секреты в Git для GitOps, один кластер | Sealed Secrets (`kubeseal`) |
| Секреты в Git, несколько сред/облачный KMS, не только k8s | SOPS (+ age / KMS) |
| Центральное хранилище, аудит, ротация, несколько кластеров | Vault / OpenBao + External Secrets Operator |
| Динамические учётки БД с TTL | Vault database secrets engine |
| EKS + AWS Secrets Manager | ESO + IRSA (без ключей в кластере) |
| Минимум без внешних систем | k8s Secret + шифрование etcd (`EncryptionConfiguration`) + RBAC |

## k8s Secret

| Задача | Команда |
| :--- | :--- |
| Создать из литерала / файла | `kubectl create secret generic db --from-literal=password=... --from-file=ca.crt` |
| Прочитать значение ⚠️ | `kubectl get secret db -o jsonpath='{.data.password}' \| base64 -d` |
| Все ключи секрета | `kubectl get secret db -o json \| jq '.data \| map_values(@base64d)'` |
| Манифест без применения | `kubectl create secret generic db --from-literal=k=v --dry-run=client -o yaml` |

⚠️ base64 — кодирование, не шифрование. Без `EncryptionConfiguration`
секреты лежат в etcd открытым текстом.

## Vault / OpenBao CLI

`bao` (OpenBao) принимает те же подкоманды, что и `vault`.

| Задача | Команда |
| :--- | :--- |
| Адрес и статус | `export VAULT_ADDR=https://vault:8200`<br>`vault status` |
| Логин токеном / userpass | `vault login` / `vault login -method=userpass username=alice` |
| Логин из Pod (kubernetes auth) | `vault write auth/kubernetes/login role=myapp jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token` |
| Записать KV v2 | `vault kv put -mount=secret myapp/config api_key=... db_password=...` |
| Прочитать / одно поле | `vault kv get -mount=secret myapp/config`<br>`vault kv get -mount=secret -field=db_password myapp/config` |
| Версии / откат | `vault kv get -mount=secret -version=1 myapp/config`<br>`vault kv rollback -mount=secret -version=1 myapp/config` |
| Частичное обновление | `vault kv patch -mount=secret myapp/config api_key=new` |
| Удалить навсегда ⚠️ | `vault kv metadata delete -mount=secret myapp/config` |
| Динамическая учётка БД | `vault read database/creds/myapp-role` |
| Lease: продлить / отозвать | `vault lease renew <lease_id>` / `vault lease revoke -prefix database/creds/myapp-role` |
| Политика | `vault policy write myapp myapp.hcl` / `vault policy read myapp` |
| Кто я (токен) | `vault token lookup` |

```hcl
# myapp.hcl — KV v2: путь данных содержит /data/
path "secret/data/myapp/*" {
  capabilities = ["read"]
}
```

⚠️ `vault login -method=kubernetes` не существует: у kubernetes auth нет
CLI-помощника, только `vault write auth/kubernetes/login`.

## External Secrets Operator

```yaml
apiVersion: external-secrets.io/v1      # v1beta1 больше не обслуживается
kind: ExternalSecret
metadata: {name: myapp-db, namespace: prod}
spec:
  refreshInterval: 1h
  secretStoreRef: {name: vault-backend, kind: ClusterSecretStore}
  target: {name: myapp-db, creationPolicy: Owner}
  data:
    - secretKey: password
      remoteRef: {key: myapp/database, property: password}
```

| Задача | Команда |
| :--- | :--- |
| Статус синхронизации | `kubectl get externalsecret -A` (колонки `STATUS`, `READY`) |
| Почему не синхронизируется | `kubectl describe externalsecret myapp-db -n prod` (Events) |
| Store подключён? | `kubectl get clustersecretstore` (`READY=True`) |
| Принудительно пересинхронизировать | `kubectl annotate es myapp-db force-sync=$(date +%s) --overwrite -n prod` |

## Sealed Secrets

| Задача | Команда |
| :--- | :--- |
| Публичный ключ контроллера | `kubeseal --fetch-cert > pub-cert.pem` (нестандартная установка: `--controller-name`, `--controller-namespace`) |
| Зашифровать Secret | `kubectl create secret generic db --from-literal=password=... --dry-run=client -o yaml \| kubeseal --cert pub-cert.pem -o yaml > db-sealed.yaml` |
| Одно значение | `echo -n 's3cr3t' \| kubeseal --raw --name db --namespace prod --cert pub-cert.pem` |
| Добавить ключ в существующий | `... \| kubeseal --merge-into db-sealed.yaml` |
| Перешифровать новым ключом | `kubeseal --re-encrypt < old.yaml > new.yaml` |
| Проверить, что расшифруется | `kubeseal --validate < db-sealed.yaml` |

⚠️ По умолчанию scope `strict`: SealedSecret привязан к имени и
namespace — переименование ломает расшифровку. Бэкап приватного ключа
контроллера обязателен, иначе при потере кластера секреты не восстановить.

## SOPS

| Задача | Команда |
| :--- | :--- |
| Зашифровать (age) | `sops encrypt --age age1... secrets.yaml > secrets.enc.yaml` |
| Только поля data/stringData | `sops encrypt --encrypted-regex '^(data\|stringData)$' --age age1... s.yaml` |
| Расшифровать / редактировать | `sops decrypt secrets.enc.yaml` / `sops edit secrets.enc.yaml` |
| Правила по путям | `.sops.yaml` с `creation_rules` (`path_regex`, `age`, `kms`) |

## Утечки

| Задача | Команда |
| :--- | :--- |
| Скан истории репо | `gitleaks git -v .` |
| Скан каталога без git | `gitleaks dir .` |
| pre-commit (только staged) | `gitleaks git --pre-commit --staged` |
| Отчёт для CI | `gitleaks git --redact --report-format sarif --report-path gitleaks.sarif` |
| Файлы `.env` в истории | `git log --all --full-history -- '*.env'` |

⚠️ Секрет, попавший в Git, считается скомпрометированным — сначала
ротация, потом чистка истории.

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| ExternalSecret `SecretSyncedError` | `describe externalsecret`; путь/`property`; политика роли Vault |
| `permission denied` в Vault на KV v2 | в политике нет `/data/` в пути |
| SealedSecret не создаёт Secret | логи `sealed-secrets-controller`; имя/namespace совпадают со scope |
| `403` при `auth/kubernetes/login` | `bound_service_account_names/namespaces` роли; audience токена |

> Проверка: `vault` (v2.1.2: `kv`, `lease`, `policy`, ошибка
> `-method=kubernetes`), `kubeseal` 0.32.2, `sops` v3.11.0, `gitleaks`
> v8.28.0 — `--help` в Docker; ESO: served-версии CRD в актуальном
> bundle.yaml (v1). Не проверено: работа против живого Vault/кластера.
