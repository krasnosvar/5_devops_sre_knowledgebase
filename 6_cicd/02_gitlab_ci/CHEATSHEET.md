# GitLab CI — шпаргалка

Подробности и объяснения — в [gitlab_ci.md](./01_theory/gitlab_ci.md).
⚠️ — опасная команда или частая ловушка.

## Ключевые слова `.gitlab-ci.yml`

| Задача | Ключ |
| :--- | :--- |
| Порядок стадий | `stages: [build, test, deploy]` |
| Когда запускать джобу | `rules: - if: / changes: / exists: / when:` (вместо устаревших `only/except`) |
| Когда создавать пайплайн вообще | `workflow: rules:` |
| Стартовать сразу после конкретной джобы (DAG) | `needs: [build_backend]` |
| Стартовать сразу, ни от кого не завися | `needs: []` |
| Не качать артефакты зависимости | `needs: [{job: build, artifacts: false}]` / `dependencies: []` |
| Передать файлы следующим джобам | `artifacts: paths: [...]`, `expire_in: 1 week` |
| Отчёт тестов в MR | `artifacts: reports: junit: report.xml` |
| Передать переменную в другую джобу | `artifacts: reports: dotenv: build.env` |
| Ускорить (кэш зависимостей) | `cache: key: files: [package-lock.json]`, `paths: [node_modules/]` |
| Только читать кэш | `cache: policy: pull` |
| Окружение и URL | `environment: name: production`, `url: https://...` |
| Остановить review app | `environment: on_stop: stop_review` + у стоп-джобы `action: stop` |
| Авто-удаление окружения | `environment: auto_stop_in: 1 day` |
| Ручной запуск | `rules: - if: ... when: manual` |
| Не два деплоя одновременно | `resource_group: production` |
| Шаблон / наследование | `.tpl:` (скрытая джоба) + `extends: .tpl` |
| Взять кусок другой джобы | `script: [!reference [.setup, script]]` |
| Подключить файлы | `include: - local: / project: + ref: + file: / remote: / template: / component:` |
| Параллельные варианты | `parallel: matrix: - PY: ["3.11", "3.12"]` |
| Дочерний пайплайн | `trigger: include: child.yml`, `strategy: depend` |
| Отменять устаревшие запуски | `interruptible: true` |
| Повтор при сбое раннера | `retry: max: 2, when: [runner_system_failure]` |
| JWT для Vault/облака | `id_tokens: VAULT_ID_TOKEN: aud: https://vault.example.com` |

## Типовые `rules`

```yaml
workflow:
  rules:
    # MR-пайплайн вместо дубля branch-пайплайна
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS
      when: never
    - if: $CI_COMMIT_BRANCH

deploy_prod:
  stage: deploy
  environment:
    name: production
  resource_group: production
  rules:
    - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/
      when: manual
    - when: never

test_service_a:
  stage: test
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      changes: ["src/service_A/**/*"]
  script: [make -C src/service_A test]
```

## Передача переменной между джобами (dotenv)

```yaml
build:
  stage: build
  script:
    - echo "VERSION=1.0.$CI_PIPELINE_IID" > build.env
  artifacts:
    reports:
      dotenv: build.env

deploy:
  stage: deploy
  needs: [build]
  script:
    - echo "deploy $VERSION"
```

## Artifacts vs Cache

| | Artifacts | Cache |
| :--- | :--- | :--- |
| Зачем | результат сборки, передача между джобами | ускорение |
| Гарантия | есть: качаются в джобы следующих стадий | нет: может отсутствовать |
| Где хранится | GitLab Server, скачивается в UI | у раннера или S3 (distributed cache) |
| Пример | бинарник, `report.xml`, `build.env` | `node_modules/`, `~/.m2`, `.cache/pip` |

## Предопределённые переменные

| Переменная | Что |
| :--- | :--- |
| `CI_PIPELINE_SOURCE` | `push`, `merge_request_event`, `schedule`, `web`, `trigger` |
| `CI_COMMIT_BRANCH` / `CI_COMMIT_TAG` | ветка (нет в MR-пайплайне) / тег |
| `CI_DEFAULT_BRANCH` | обычно `main` |
| `CI_COMMIT_SHORT_SHA` | неизменяемый тег образа |
| `CI_REGISTRY`, `CI_REGISTRY_IMAGE` | registry проекта и путь образа |
| `CI_REGISTRY_USER` / `CI_REGISTRY_PASSWORD` | логин в registry на базе `CI_JOB_TOKEN` |
| `CI_JOB_TOKEN` | токен джобы для API/registry/пакетов, живёт пока идёт джоба |
| `CI_API_V4_URL` | базовый URL API |

## Сборка образов в CI

| Способ | Привилегии | Когда |
| :--- | :--- | :--- |
| DinD: `services: [docker:dind]`, `DOCKER_TLS_CERTDIR: "/certs"` | ⚠️ `--privileged` | только изолированные раннеры |
| DooD: сокет `/var/run/docker.sock` | ⚠️ root на хосте через сокет | не для общих раннеров |
| BuildKit rootless: `moby/buildkit:*-rootless`, `buildctl-daemonless.sh build ...` | без `--privileged`, ослабленный seccomp | Kubernetes executor, дефолт для новых пайплайнов |
| Buildah: `buildah build --storage-driver vfs` | rootless | Red Hat-стек |
| Kaniko | — | ⚠️ репозиторий Google архивирован в 2025, только форки |

```bash
# BuildKit rootless в джобе (образ moby/buildkit:rootless,
# BUILDKITD_FLAGS=--oci-worker-no-process-sandbox)
buildctl-daemonless.sh build --frontend dockerfile.v0 \
  --local context=. --local dockerfile=. \
  --output type=image,name="$CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA",push=true \
  --export-cache type=registry,ref="$CI_REGISTRY_IMAGE:cache" \
  --import-cache type=registry,ref="$CI_REGISTRY_IMAGE:cache"
```

## GitLab Runner

| Задача | Команда |
| :--- | :--- |
| Зарегистрировать (GitLab 16+, токен из UI `glrt-...`) | `gitlab-runner register --non-interactive --url https://gitlab.example.com --token glrt-... --executor docker --docker-image alpine:3.20` |
| Список раннеров в `config.toml` | `gitlab-runner list` |
| Проверить связь с сервером | `gitlab-runner verify` |
| Удалить мёртвые записи из `config.toml` | `gitlab-runner verify --delete` |
| Снять регистрацию ⚠️ | `gitlab-runner unregister --name <name>` / `--all-runners` |
| Конфиг | `/etc/gitlab-runner/config.toml` (root), `concurrent`, `check_interval` (3 с) |
| Ресурсы пода (k8s executor) | `cpu_request`, `memory_request`, `memory_limit`; helper/service: `helper_memory_limit`, `service_memory_limit` |

| Executor | Изоляция | Когда |
| :--- | :--- | :--- |
| `shell` | нет, мусорит на хосте | разовые админ-задачи |
| `docker` | контейнер на джобу | VM-раннеры |
| `kubernetes` | под на джобу | масштабирование, автоскейлинг |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| Следующая джоба не видит бинарник | не указан в `artifacts:paths`; каждая джоба в чистом контейнере |
| Джоба не попала в пайплайн | `rules` (первое совпадение решает), `changes` в не-MR пайплайне, `workflow:rules` |
| Два пайплайна на один пуш (branch + MR) | `workflow: rules` с `$CI_OPEN_MERGE_REQUESTS` |
| Переменная пустая в feature-ветке | переменная `Protected` — доступна только на защищённых ветках/тегах |
| Пустой `$CI_JOB_JWT` после апгрейда | удалён в GitLab 17.0 → `id_tokens:` |
| Кэш всегда пуст | разные раннеры без distributed cache, ключ `cache:key` меняется |
| Developer нажал Play на prod | Protected Environments (Settings → CI/CD) |
| OOMKilled на k8s executor | лимит не того контейнера (build/helper/svc), нет `memory_request` |
| Pending: «no runners» | теги джобы ≠ тегам раннера, раннер `protected`, `run untagged` выключен |

## Ловушки

- ⚠️ Если джобу из `needs` отрезали `rules`, пайплайн не создастся —
  нужен `needs: [{job: build, optional: true}]`.
- ⚠️ `changes:` надёжно работает в MR-пайплайнах; в branch-пайплайне
  без `compare_to` сравнивает только с предыдущим пушем.
- ⚠️ Masked переменная — это строковая замена в логе, `| base64` её
  обходит.
- `artifacts: expire_in` ставить всегда, иначе хранилище растёт.

> Проверка: `gitlab-runner` 18.3 (`register/list/verify/unregister --help`
> в `gitlab/gitlab-runner:v18.3.0`), YAML-фрагменты — `yamllint`;
> не проверено: семантика `.gitlab-ci.yml` на живом GitLab (CI Lint
> недоступен локально).
