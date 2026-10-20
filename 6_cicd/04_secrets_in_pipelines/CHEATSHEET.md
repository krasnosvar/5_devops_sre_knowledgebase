# Секреты в пайплайнах — шпаргалка

Подробности и объяснения — в
[secrets_in_ci.md](./01_theory/secrets_in_ci.md). ⚠️ — опасная команда
или частая ловушка.

## Что выбрать

| Что нужно | Чем | Почему |
| :--- | :--- | :--- |
| Доступ CI в облако (AWS/GCP/Azure) | OIDC federation | нет статических ключей, STS на ~1 час |
| Пароли к внутренним БД/сервисам | Vault, JWT auth из CI | короткий Vault-токен, политика на проект/ветку |
| Пароль, которого вообще не должно быть заранее | Vault dynamic secrets | пользователь БД создаётся на TTL и удаляется |
| Секреты рядом с манифестами в Git | SOPS + KMS/age | в Git только шифротекст |
| Только AWS, ротация RDS | AWS Secrets Manager | managed, но vendor lock-in |
| Не дать секрету утечь в Git | Gitleaks/TruffleHog в CI + pre-commit | ловят до мержа |

## GitLab: JWT через `id_tokens`

```yaml
deploy:
  id_tokens:
    VAULT_ID_TOKEN:
      aud: https://vault.example.com
  script:
    - export VAULT_ADDR=https://vault.example.com
    - export VAULT_TOKEN="$(vault write -field=token auth/jwt/login
      role=myproject-prod jwt="$VAULT_ID_TOKEN")"
    - vault kv get -field=password secret/myproject/db
```

| Claim в JWT GitLab | Для чего в `bound_claims` |
| :--- | :--- |
| `aud` | сверка с `bound_audiences` роли |
| `project_path` | только этот проект |
| `ref`, `ref_type` | только ветка `main` / теги |
| `ref_protected` | только защищённые ветки |
| `environment` | только джобы окружения `production` |

⚠️ `CI_JOB_JWT` / `CI_JOB_JWT_V2` удалены в GitLab 17.0 — только
`id_tokens:`. В GitHub Actions аналог — `permissions: id-token: write`.

## Vault

| Задача | Команда |
| :--- | :--- |
| Включить JWT auth | `vault auth enable jwt` |
| Указать издателя (GitLab) | `vault write auth/jwt/config oidc_discovery_url="https://gitlab.example.com" bound_issuer="https://gitlab.example.com"` |
| Роль для проекта | `vault write auth/jwt/role/myproject-prod role_type=jwt user_claim=project_path bound_audiences=https://vault.example.com bound_claims='{"project_path":"group/myproject","ref":"main","ref_protected":"true"}' token_policies=myproject-read token_ttl=5m` |
| Логин из джобы | `vault write -field=token auth/jwt/login role=myproject-prod jwt="$VAULT_ID_TOKEN"` |
| Логин CLI-методом | `vault login -method=jwt role=myproject-prod jwt="$VAULT_ID_TOKEN"` |
| Прочитать KV v2 | `vault kv get -field=password secret/myproject/db` |
| Динамический пароль БД | `vault read database/creds/ci-readonly` |
| Проверить свой токен | `vault token lookup` |
| AppRole (если нет OIDC) | `vault write auth/approle/login role_id=... secret_id=...` |

## SOPS

| Задача | Команда |
| :--- | :--- |
| Ключ age | `age-keygen -o key.txt` (публичный: `age-keygen -y key.txt`) |
| Зашифровать (age) | `sops encrypt --age age1... secrets.yaml > secrets.enc.yaml` |
| Зашифровать (AWS KMS) | `sops encrypt --kms arn:aws:kms:...:key/... --in-place secrets.yaml` |
| Шифровать только значения нужных ключей | `--encrypted-regex '^(data\|stringData\|password)$'` |
| Расшифровать в stdout | `sops decrypt secrets.enc.yaml` |
| Редактировать | `sops edit secrets.enc.yaml` |
| Запустить с секретами в env | `sops exec-env secrets.enc.yaml './deploy.sh'` |
| Перешифровать после смены получателей | `sops updatekeys secrets.enc.yaml` |
| Ротировать data key | `sops rotate --in-place secrets.enc.yaml` |
| Ключ для расшифровки age | `SOPS_AGE_KEY_FILE=key.txt` |

```yaml
# .sops.yaml — правила, чтобы не передавать ключи флагами
creation_rules:
  - path_regex: envs/prod/.*\.yaml$
    kms: arn:aws:kms:eu-central-1:123456789012:key/abcd-1234
  - path_regex: .*\.yaml$
    age: age1p80573t5jq5jd7lf2v0k3sg54m33hzkdc40zmuuk44zwpzlxrvhq07du7t
```

## Сканеры секретов

| Задача | Команда |
| :--- | :--- |
| Сканировать историю Git | `gitleaks git -v .` |
| Только новые коммиты (CI) | `gitleaks git --log-opts="origin/main..HEAD" .` |
| Pre-commit (staged) | `gitleaks git --staged` |
| Каталог без Git | `gitleaks dir .` |
| Отчёт SARIF, секреты скрыты | `gitleaks git --redact --report-format sarif --report-path gl.sarif .` |
| Игнорировать известные находки | `--baseline-path baseline.json` / `.gitleaksignore` |
| TruffleHog: только подтверждённые | `trufflehog git file://. --results=verified --fail` |
| TruffleHog с коммита | `trufflehog git file://. --since-commit main --fail` |

## Masking и Protected

| Механизм | Что даёт | Чего не даёт |
| :--- | :--- | :--- |
| Masked | замена точного значения на `[MASKED]`/`***` в логе | ⚠️ `\| base64`, `rev`, посимвольный вывод обходят |
| Protected (GitLab) | переменная только на защищённых ветках/тегах | защиты от Maintainer |
| Environment-scoped | секрет только джобам окружения | — |
| Protected Environments | деплой только разрешённым ролям | — |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| `permission denied` при Vault-логине | `aud` ≠ `bound_audiences`, claim не совпал с `bound_claims` (`ref`, `ref_protected`) |
| Пустой `$CI_JOB_JWT` | удалён в 17.0 → `id_tokens:` |
| `sops: no matching creation rules` | `path_regex` в `.sops.yaml` не подходит к файлу |
| `failed to get the data key` | нет доступа к KMS / нет `SOPS_AGE_KEY_FILE` |
| Секрет в публичном репо, уже force-push | ⚠️ считать скомпрометированным: отозвать и сменить |

> Проверка: `sops` 3.10.2 (`encrypt/decrypt/edit/exec-env/updatekeys/
> rotate`, флаги `--age/--kms/--encrypted-regex/--in-place`; round-trip
> `encrypt --age` → `decrypt` выполнен в scratch), `gitleaks`
> 8.24.3, `trufflehog` 3.90.6, `vault` 1.20.3, `age-keygen` — по `--help`;
> не проверено: настройка JWT auth (`auth/jwt/config`, роль с
> `bound_claims`) на живом Vault и GitLab, `sops --kms`.
