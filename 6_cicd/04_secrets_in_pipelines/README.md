# 04. Секреты в пайплайнах

## Зачем
CI-система — точка, где сходятся доступы ко всему: registry, облако,
базы, кластеры. Статический ключ в переменных CI — типовой источник
утечек. Тема о том, как получать короткоживущие доступы (OIDC, Vault JWT
auth), шифровать секреты в Git (SOPS) и не светить их в логах.

## Пререквизиты
-  [02_gitlab_ci](../02_gitlab_ci/) или
  [03_github_actions](../03_github_actions/)
  — переменные CI, environments, `permissions`.
- [10_devsecops/02_secrets_management](../../10_devsecops/02_secrets_management/)
  — **забегание вперёд**: Vault и External Secrets подробно там. Здесь
  достаточно понимать, что Vault выдаёт секреты по токену и умеет
  проверять JWT (auth method `jwt`).

## Файлы
- [01_theory/secrets_in_ci.md](./01_theory/secrets_in_ci.md) — почему
  статические ключи плохи, OIDC, Vault JWT auth и `id_tokens` в GitLab,
  SOPS, masking и secret scanning, вопросы с собеседований.
- [02_examples/](./02_examples/):
  - [vault-oidc-gitlab.sh](./02_examples/vault-oidc-gitlab.sh) — логин
    джобы GitLab в Vault через `id_tokens` и чтение секретов в env;
  - [.env.example](./02_examples/.env.example) — шаблон `.env` для
    локальной разработки (что коммитить, что нет).

Без упражнений: полноценная лаба требует Vault и настроенный OIDC-trust;
практика с Vault — в
[10_devsecops/02_secrets_management](../../10_devsecops/02_secrets_management/).

## Как проходить
1. Теория.
2. Прочитать `vault-oidc-gitlab.sh` вместе с примером джобы в его шапке:
   где берётся JWT, что проверяет Vault, куда попадают секреты.
3. Ответить на Interview Q&A.

## Когда двигаться дальше
- Можете объяснить, почему маскирование в логах не защищает от
  `echo $SECRET | base64`.
- Можете написать джобу GitLab с `id_tokens` и `aud` и объяснить, почему
  `CI_JOB_JWT_V2` больше не работает.
- Можете объяснить, как Protected variables + Protected environments
  закрывают доступ к прод-секретам из feature-веток.

Дальше: [05_gitops_cd](../05_gitops_cd/).
