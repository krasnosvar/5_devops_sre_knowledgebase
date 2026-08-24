# Раздел 5. CI/CD

Пайплайны, автоматизация сборки и деплоя, GitOps. Теория и практика на GitLab CI
и GitHub Actions; интеграция с ArgoCD для CD-части.

## Подразделы

1. [01_pipeline_theory](./01_pipeline_theory/) — фундаментальные концепции:
   стадии, артефакты, кэш, параллельность; trunk-based development vs feature branches;
   DORA-метрики (deployment frequency, lead time, MTTR, change failure rate).

2. [02_gitlab_ci](./02_gitlab_ci/) — GitLab CI: `.gitlab-ci.yml` структура,
   stages/jobs/rules, cache и artifacts, environments, защищённые переменные,
   self-hosted runners (Docker executor vs shell executor), merge request pipelines.

3. [03_github_actions](./03_github_actions/) — GitHub Actions: workflow/job/step,
   matrix builds, reusable workflows, composite actions, secrets и environments,
   self-hosted runners, OIDC для бессекретной авторизации в AWS/GCP.

4. [04_secrets_in_pipelines](./04_secrets_in_pipelines/) — как правильно работать
   с секретами в CI: masked переменные, Vault Agent Injector в k8s, OIDC token
   вместо статических ключей, ротация; что никогда не делать (секреты в логах,
   в артефактах, в ENV без маски).

5. [05_gitops_cd](./05_gitops_cd/) — GitOps для CD: pull-based модель (ArgoCD,
   Flux) vs push-based (pipeline → kubectl apply); image update automation;
   promotion между окружениями (dev → staging → prod) через PR/merge в git.

6. [06_testing_in_pipelines](./06_testing_in_pipelines/) — слои тестирования в CI:
   lint → unit → integration → e2e → smoke; test containers; параллелизация;
   flaky tests и как с ними работать.

## Как проходить

01 → 02 или 03 (по используемой платформе) → 04 → 05 → 06.
Разделы 02 и 03 независимы — достаточно одного.

## Упражнения — тиры

🐳 Tier 1: GitLab CE или Gitea + Woodpecker CI в Docker Compose
🖥 Tier 2: self-hosted GitLab runner на VM
☁️ Tier 3: GitHub Actions (бесплатные минуты на public repos) или GitLab.com
