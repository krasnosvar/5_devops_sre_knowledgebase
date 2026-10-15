# Шаг 5 — CI/CD: тесты, сборка образа и деплой из пайплайна

🐳 Tier 1 (GitLab + runner) + кластер из шага 3 или 4. Теория —
[6_cicd](../../../6_cicd/): [02_gitlab_ci](../../../6_cicd/02_gitlab_ci/)
(stages, jobs, rules, registry) и
[06_testing_in_pipelines](../../../6_cicd/06_testing_in_pipelines/).

На шагах 1–4 обновление приложения было ручным: scp, `docker build`,
`kind load`, `kubectl apply`. Здесь то же самое делает пайплайн на каждый
коммит в `main`.

## Что лежит в папке

- [.gitlab-ci.yml](.gitlab-ci.yml) — три стадии:
  - `test` — ставит зависимости приложения + `fakeredis pytest httpx`,
    копирует тесты в `app/` и запускает `pytest`;
  - `build` — собирает образ из `app/Dockerfile` через Docker-in-Docker и
    пушит в registry проекта (`$CI_REGISTRY_IMAGE/shortener:<short sha>`);
  - `deploy` — скачивает kubectl с `dl.k8s.io` и делает
    `kubectl set image` + `rollout status` для `deployment/shortener`.
  `build` и `deploy` запускаются только для ветки `main`.
- [tests/test_app.py](tests/test_app.py) — 4 теста API (`/health`,
  `/shorten` + редирект, `/shorten` без url → 400, неизвестный код → 404).
  Redis подменяется на `fakeredis`, поэтому тестам не нужен живой Redis.

## Прогнать тесты локально

Из папки `05_cicd/`:

```bash
python3 -m venv /tmp/shortener-venv
/tmp/shortener-venv/bin/pip install -r ../app/requirements.txt \
  fakeredis pytest httpx
cd tests/
PYTHONPATH=../../app /tmp/shortener-venv/bin/pytest -v -p no:cacheprovider
```

Ожидаемо: `4 passed`.

## Запустить пайплайн в GitLab

> Нужен git: `init`, `add`, `commit`, `remote add`, `push`. Если git ещё
> не освоен — основы в соседнем репозитории
> [01_git_essentials](../../../../4_python_my_knowledgebase/0_tooling_and_workflow/01_git_essentials/).

1. Создать пустой проект в GitLab и скопировать в его корень содержимое
   `05_capstone_project/`, а `05_cicd/.gitlab-ci.yml` — в корень репозитория
   (GitLab читает пайплайн только оттуда).
2. Runner для `build` должен поддерживать Docker-in-Docker (privileged).
3. В Settings → CI/CD → Variables добавить переменную `KUBECONFIG` типа
   **File** с kubeconfig кластера, доступного с runner-а (кластер из
   шага 4 или облачный; kind на ноутбуке с shared runner-а недоступен).
4. В кластере должны быть уже применены манифесты из
   [03_kubernetes/manifests](../03_kubernetes/manifests/), а кластер — уметь
   тянуть образ из registry GitLab (для приватного проекта — через
   `imagePullSecrets`).
5. `git push` в `main` → пайплайн test → build → deploy.

## Что почувствовать на этом шаге

- Сломайте тест (например, ожидайте 201 вместо 200) и запушьте — `build` и
  `deploy` не запустятся: стадия `test` — это ворота.
- Тег образа = `CI_COMMIT_SHORT_SHA`: по поду в кластере видно, какой
  коммит в нём работает (`kubectl -n shortener get deploy shortener -o
  jsonpath='{..image}'`).
- Деплой здесь — push-модель (pipeline сам ходит в кластер с kubeconfig).
  Альтернатива — pull-модель GitOps:
  [4_kubernetes/09_gitops](../../../4_kubernetes/09_gitops/).
