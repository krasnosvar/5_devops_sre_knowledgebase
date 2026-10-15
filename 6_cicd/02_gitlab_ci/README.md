# 02. GitLab CI

## Зачем
GitLab CI — одна из самых распространённых CI-систем в компаниях с
self-hosted GitLab. На работе придётся писать и чинить `.gitlab-ci.yml`,
ускорять пайплайны (cache, `needs`), ограничивать деплой в прод
(`rules`, protected environments) и поднимать собственные раннеры.

## Пререквизиты
- [01_pipeline_theory](../01_pipeline_theory/) — стадии CI/CD и стратегии
  деплоя.
-  [Git:
  основы](../../../4_python_my_knowledgebase/0_tooling_and_workflow/01_git_essentials/)
  (соседний репозиторий) — push, ветки, merge request.
- [3_containers](../../3_containers/) — каждая джоба docker executor
  запускается в контейнере из `image:`; стенд поднимается через
  Docker Compose
  ([06_compose_patterns](../../3_containers/06_compose_patterns/)).

> **Забегание вперёд.** Джобы деплоя в примере используют `kubectl`,
> который подробно разбирается в [4_kubernetes](../../4_kubernetes/).
> Для этой темы достаточно понимать, что `kubectl set image` меняет образ
> Deployment, а `kubectl rollout status` ждёт окончания раскатки. Если
> Kubernetes ещё не освоен — деплой-джобы можно пропустить.

## Файлы
- [01_theory/gitlab_ci.md](./01_theory/gitlab_ci.md) — Server/Runner/
  executors, регистрация раннера (GitLab 16+), cache vs artifacts, DAG
  (`needs`) и `rules`, dotenv-переменные, DinD и сборка без демона
  (BuildKit rootless, Buildah), вопросы с собеседований.
- [02_examples/](./02_examples/):
  - [.gitlab-ci.yml](./02_examples/.gitlab-ci.yml) — полный пайплайн
    lint → test → build → deploy staging → deploy production;
  - [docker-compose.yaml](./02_examples/docker-compose.yaml) — 🐳 Tier 1
    стенд: GitLab CE + GitLab Runner.
- [03_exercises/README.md](./03_exercises/README.md) — стенд (00) и 4
  упражнения: первый pipeline, `rules`, cache, matrix. 🐳 Tier 1 или
  ☁️ Tier 3 (GitLab.com).
- [04_exercises_answers/](./04_exercises_answers/) — ответы:
  [README.md](./04_exercises_answers/README.md) (по упражнениям) и
  итоговый
  [.gitlab-ci-answer.yml](./04_exercises_answers/.gitlab-ci-answer.yml).

## Как проходить
1. Теория (`01_theory/gitlab_ci.md`).
2. Разобрать пример `02_examples/.gitlab-ci.yml`: какие джобы когда
   запускаются и почему.
3. Поднять стенд и зарегистрировать раннер (упражнение 00) или завести
   проект на GitLab.com.
4. Упражнения 01-04, затем сверка с ответами.

## Когда двигаться дальше
- Можете без подсказки объяснить разницу cache и artifacts и когда
  пайплайн обязан работать без кэша.
- Можете написать `rules` для «MR + main» и «только вручную на main».
- Можете зарегистрировать раннер новым способом (токен `glrt-`) и
  объяснить, зачем ему `--docker-network-mode` на стенде.
- Можете объяснить, почему DinD опасен и чем собирать образы вместо него.

Дальше: [04_secrets_in_pipelines](../04_secrets_in_pipelines/) (или
[03_github_actions](../03_github_actions/), если нужны обе платформы).
