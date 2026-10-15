# Ответы — Secrets Management

Стенд: Vault в dev-режиме из [../02_examples/](../02_examples/)
(`docker compose up -d`). Во всех упражнениях:

```bash
export VAULT_ADDR="http://localhost:8200"
export VAULT_TOKEN="dev-root-token"
```

Время, lease_id, имена пользователей и пароли у вас будут другими.

## Упражнение 01 — Базовая работа с Vault KV

```bash
vault kv put secret/myapp/database \
  username=appuser password=s3cr3t123 host=postgres:5432
vault kv get secret/myapp/database
vault kv get -field=password secret/myapp/database

vault kv put secret/myapp/database password=newpassword123
vault kv get secret/myapp/database
vault kv get -version=1 secret/myapp/database
vault kv metadata get secret/myapp/database
```

Ожидаемый вывод (примерно так, повторяющиеся блоки Metadata сокращены):

```text
======= Secret Path =======
secret/data/myapp/database
...
version            1

====== Data ======
Key         Value
---         -----
host        postgres:5432
password    s3cr3t123
username    appuser
s3cr3t123
...
version            2

====== Data ======
Key         Value
---         -----
password    newpassword123
...
version            1
...
host        postgres:5432
password    s3cr3t123
username    appuser
======== Metadata Path ========
secret/metadata/myapp/database
...
current_version         2
...
====== Version 1 ======
...
====== Version 2 ======
...
```

Почему так: в KV v2 каждый `put` создаёт новую версию целиком, а не
дописывает поля — поэтому в версии 2 остался только `password`. Для
частичного обновления есть `vault kv patch`. Старые версии доступны
через `-version`, пока не превышен `max_versions`.

## Упражнение 02 — Динамические секреты для PostgreSQL

Команды — из условия упражнения (`docker run ... postgres`,
`vault secrets enable database`, `vault write database/config/myapp`,
`vault write database/roles/app-role`). Затем:

```bash
vault read database/creds/app-role
vault read database/creds/app-role

# Убедиться, что роль реально создана в PostgreSQL
docker exec postgres psql -U postgres -d appdb -c '\du'

# Досрочно отозвать все выданные credentials
vault lease revoke -prefix database/creds/app-role
docker exec postgres psql -U postgres -d appdb -c '\du'
```

Ожидаемый вывод (примерно так):

```text
Success! Enabled the database secrets engine at: database/
Success! Data written to: database/config/myapp
Success! Data written to: database/roles/app-role
Key                Value
---                -----
lease_id           database/creds/app-role/0TCFnWlUB6RpglHKFczSvuqI
lease_duration     1h
lease_renewable    true
password           v6sg-BFjmCK3dzzxykfQ
username           v-token-app-role-sAJ99xY2fchy8JqNI2TO-1791996929
(второй read — другие username и password)
                    Role name                     |      Attributes
--------------------------------------------------+-------------------------
 postgres                                         | Superuser, Create role...
 v-token-app-role-sAJ99xY2fchy8JqNI2TO-1791996929 | Password valid until ...
All revocation operations queued successfully!
 Role name |                         Attributes
-----------+----------------------------------------------------------
 postgres  | Superuser, Create role, Create DB, Replication, Bypass RLS
```

Почему так: Vault подключается к PostgreSQL как администратор и по
шаблону `creation_statements` создаёт отдельную роль на каждый запрос.
Каждый набор credentials привязан к lease: по истечении TTL или при
`revoke` Vault удаляет роль в БД — утёкший пароль живёт максимум час.

## Упражнение 03 — Policy — принцип наименьших привилегий

Команды — из условия. Для наглядности добавьте попытку записи:

```bash
vault policy write app-policy /tmp/app-policy.hcl
APP_TOKEN=$(vault token create -policy=app-policy -format=json \
  | jq -r '.auth.client_token')

VAULT_TOKEN=$APP_TOKEN vault kv get secret/myapp/database
VAULT_TOKEN=$APP_TOKEN vault kv list secret/
VAULT_TOKEN=$APP_TOKEN vault kv put secret/myapp/database password=x
```

Ожидаемый вывод (примерно так):

```text
Success! Uploaded policy: app-policy
======= Secret Path =======
secret/data/myapp/database
...
password    newpassword123
Error listing secret/metadata: Error making API request.

URL: GET http://localhost:8200/v1/secret/metadata?list=true
Code: 403. Errors:

* 1 error occurred:
	* permission denied
Error writing data to secret/data/myapp/database: Error making API
request.

URL: PUT http://localhost:8200/v1/secret/data/myapp/database
Code: 403. Errors:

* 1 error occurred:
	* permission denied
```

Почему так: в KV v2 данные лежат под `secret/data/...`, а list и
история версий — под `secret/metadata/...`. Policy даёт только `read`
на `data/myapp/*`, поэтому `list` (в том числе `vault kv list
secret/myapp/`) и запись запрещены. Capability `list` на пути `data/`
ничего не даёт — для листинга нужен путь `metadata/`.

## Упражнение 04 — gitleaks — найти утечки секретов

Команды — из условия (ключ и пароль генерируются случайно: известный
документальный ключ `AKIAIOSFODNN7EXAMPLE` gitleaks пропускает по
allowlist, а пароль вроде `supersecret123` — по порогу энтропии).
Проверить можно и без установки, через Docker:

```bash
cd /tmp/test-repo
docker run --rm -v "$PWD:/repo" zricethezav/gitleaks:latest \
  git --verbose /repo
echo "exit code: $?"
```

Ожидаемый вывод (примерно так):

```text
Finding:     DB_PASSWORD = "zs3t5Sg0k9QGQmUzvVL+fP2W"
Secret:      zs3t5Sg0k9QGQmUzvVL+fP2W
RuleID:      generic-api-key
Entropy:     4.418296
File:        config.py
Line:        2
Commit:      ea11f3f863116b2c36178a19314e0ebef2ca80b0
...
Finding:     AKIAMSDBS33EMC5FTFH2
Secret:      AKIAMSDBS33EMC5FTFH2
RuleID:      aws-access-token
Entropy:     3.821928
File:        config.py
Line:        1
...
INF 1 commits scanned.
WRN leaks found: 2
exit code: 1
```

Как правильно исправить — порядок важен:

1. **Сначала ротировать** скомпрометированные ключи (отозвать в IAM,
   сменить пароль БД): после push секрет надо считать утёкшим, даже
   если история потом будет вычищена.
2. Убрать значения из кода — читать из переменных окружения или из
   Vault; локальный `.env` добавить в `.gitignore`.
3. Вычистить историю: `git filter-repo` или BFG Repo-Cleaner, затем
   force-push и пересоздание клонов/форков.
4. Добавить gitleaks в pre-commit hook и в CI — ненулевой exit code
   (1 при найденных утечках) роняет pipeline.

Почему так: gitleaks сканирует всю историю коммитов, а не только
текущие файлы, — удаление секрета новым коммитом его не скрывает.

Остановить стенд: `docker rm -f postgres` и `docker compose down` в
`../02_examples/`.
