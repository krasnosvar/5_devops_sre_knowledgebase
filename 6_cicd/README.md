# Раздел 6. CI/CD

Пайплайны, автоматизация сборки и деплоя, GitOps. Теория и практика на
GitLab CI и GitHub Actions; CI-сторона GitOps для CD-части.

## Пререквизиты

-  [Git:
  основы](../../4_python_my_knowledgebase/0_tooling_and_workflow/01_git_essentials/)
  (соседний репозиторий) — коммиты, ветки, merge/pull request: пайплайны
  запускаются на эти события. Git в этой базе не преподаётся.
- [3_containers](../3_containers/) — образы, registry, Docker Compose:
  джобы выполняются в контейнерах, результат CI — образ, стенд GitLab
  поднимается в Compose.
- [4_kubernetes](../4_kubernetes/) — для CD-части (деплой через
  `kubectl`, GitOps в [05_gitops_cd](./05_gitops_cd/) опирается на
  [4_kubernetes/09_gitops](../4_kubernetes/09_gitops/)). Темы 01-04 и 06
  можно проходить без него, пропуская деплой-джобы.

## Подразделы

1. [01_pipeline_theory](./01_pipeline_theory/) — фундаментальные концепции:
   стадии, артефакты, кэш, параллельность; trunk-based development vs feature
   branches;
   DORA-метрики (deployment frequency, lead time, MTTR, change failure rate).

2. [02_gitlab_ci](./02_gitlab_ci/) — GitLab CI: `.gitlab-ci.yml` структура,
   stages/jobs/rules, cache и artifacts, environments, защищённые переменные,
   self-hosted runners (Docker executor vs shell executor), merge request
   pipelines.

3. [03_github_actions](./03_github_actions/) — GitHub Actions: workflow/job/step,
   matrix builds, reusable workflows, composite actions, secrets и environments,
   self-hosted runners, OIDC для бессекретной авторизации в AWS/GCP.

4. [04_secrets_in_pipelines](./04_secrets_in_pipelines/) — как правильно
   работать с секретами в CI: masked переменные, OIDC token (`id_tokens`,
   `permissions: id-token`) вместо статических ключей, Vault JWT auth,
   SOPS; что никогда не делать (секреты в логах,
   в артефактах, в ENV без маски).

5. [05_gitops_cd](./05_gitops_cd/) — CI-сторона GitOps: push vs pull с
   точки зрения пайплайна, обновление тега образа в Ops-репозитории,
   promotion между окружениями (dev → staging → prod) через MR, откат
   `git revert`. Сами агенты (ArgoCD, Flux) — в
   [4_kubernetes/09_gitops](../4_kubernetes/09_gitops/).

6. [06_testing_in_pipelines](./06_testing_in_pipelines/) — слои тестирования в CI:
   lint → unit → integration → e2e → smoke; test containers; параллелизация;
   flaky tests и как с ними работать.

## Как проходить

01 → 02 или 03 (по используемой платформе) → 04 → 05 → 06.
Разделы 02 и 03 независимы — достаточно одного.

## Упражнения — тиры

🐳 Tier 1: GitLab CE + GitLab Runner в Docker Compose
([02_gitlab_ci/02_examples/docker-compose.yaml](./02_gitlab_ci/02_examples/docker-compose.yaml))
🖥 Tier 2: self-hosted GitLab runner на VM
☁️ Tier 3: GitHub Actions (бесплатные минуты на public repos) или GitLab.com

## Когда двигаться дальше

- Можете написать пайплайн lint → test → build → deploy на GitLab CI
  или GitHub Actions с `rules`/условиями, кэшем и ручным деплоем в прод.
- Можете настроить доступ пайплайна в облако/Vault через OIDC без
  статических ключей.
- Можете объяснить, что делает CI в GitOps-модели (тег в Ops-репо,
  promotion через MR) и чего он больше не делает.
- Можете расставить тесты по стадиям и добавить smoke-проверку после
  деплоя.

Дальше: раздел [7_compute_platforms](../7_compute_platforms/).
