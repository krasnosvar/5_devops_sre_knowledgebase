# GitHub Actions — шпаргалка

Подробности и объяснения — в
[github_actions.md](./01_theory/github_actions.md). ⚠️ — опасная команда
или частая ловушка.

## Ключи workflow

| Задача | Ключ |
| :--- | :--- |
| Где лежит | `.github/workflows/*.yml` |
| Триггеры | `on: push / pull_request / schedule / workflow_dispatch / workflow_call` |
| Фильтр веток и путей | `on: push: branches: [main]`, `paths: ["src/**"]` |
| Права `GITHUB_TOKEN` | `permissions: contents: read` (не перечисленные → `none`) |
| Отменять устаревшие запуски | `concurrency: group: ${{ github.workflow }}-${{ github.ref }}`, `cancel-in-progress: true` |
| Последовательность джоб | `needs: [build]` (без него — параллельно, на разных раннерах) |
| Матрица | `strategy: matrix: os: [...], node: [...]`, `fail-fast: false`, `max-parallel` |
| Условие | `if: github.ref == 'refs/heads/main'` |
| Шаг после падения / всегда | `if: failure()` / `if: always()` (`success()` — по умолчанию) |
| Окружение с approve | `environment: production` + Protection Rules |
| Таймаут | `timeout-minutes: 30` (по умолчанию 360) |
| Контейнер-сервис (БД) | `services: postgres: image: postgres:16-alpine` |
| Переиспользуемый workflow | `jobs: x: uses: org/ci-templates/.github/workflows/build.yml@v1` + `with:` / `secrets: inherit` |
| Входы переиспользуемого | `on: workflow_call: inputs: / secrets:` |

## Передача данных

| Откуда → куда | Как |
| :--- | :--- |
| Шаг → следующие шаги (env) | `echo "VERSION=v1.2" >> "$GITHUB_ENV"` |
| Шаг → output | `echo "digest=$D" >> "$GITHUB_OUTPUT"`, читать `${{ steps.<id>.outputs.digest }}` |
| Джоба → джоба (значение) | `jobs.<id>.outputs` + `${{ needs.<id>.outputs.x }}` |
| Джоба → джоба (файлы) | `actions/upload-artifact` → `actions/download-artifact` |
| Кэш зависимостей | `actions/cache` или `cache: pip` в `setup-*` |
| Кэш Docker-слоёв | `docker/build-push-action`: `cache-from: type=gha`, `cache-to: type=gha,mode=max` |
| Добавить в `PATH` | `echo "$HOME/bin" >> "$GITHUB_PATH"` |
| Итог в UI | `echo "### ok" >> "$GITHUB_STEP_SUMMARY"` |

## OIDC в облако (без статических ключей)

```yaml
permissions:
  id-token: write   # без него action не получит JWT
  contents: read    # без него checkout не склонирует приватный репо
steps:
  - uses: actions/checkout@v4
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::123456789012:role/gha-deploy
      aws-region: eu-central-1
```

| Где | Что настроить |
| :--- | :--- |
| AWS IAM | OIDC provider `token.actions.githubusercontent.com`, `aud` = `sts.amazonaws.com` |
| Trust policy роли | условие на `sub`: `repo:my-org/my-repo:ref:refs/heads/main` или `repo:my-org/my-repo:environment:production` |
| Срок ключей | STS, по умолчанию 1 час |

## Supply chain и безопасность

| Правило | Как |
| :--- | :--- |
| Минимальные права | `permissions: {}` на уровне workflow, нужные — на уровне джобы |
| Пиннинг сторонних actions | ⚠️ по полному SHA: `uses: owner/action@<40-hex-sha> # v4.2.0` |
| Обновлять пины | Dependabot `package-ecosystem: github-actions` |
| Fork PR и секреты | ⚠️ `pull_request_target` с checkout кода из PR = выполнение чужого кода с секретами |
| Инъекция через контекст | ⚠️ не вставлять `${{ github.event.pull_request.title }}` в `run:` — передавать через `env:` |
| Секреты окружения | доступны только джобам с `environment: <name>` |

## Custom actions

| Тип | Где работает | Когда |
| :--- | :--- | :--- |
| Composite | везде | DRY набора шагов |
| Docker | только Linux-раннеры | нужен свой тулчейн в образе |
| JavaScript | Linux/Windows/macOS, быстрее Docker | логика на TS/JS |
| Reusable workflow | — | целые джобы/матрицы из центрального репо |

## CLI `gh`

| Задача | Команда |
| :--- | :--- |
| Список workflow | `gh workflow list` |
| Запустить `workflow_dispatch` | `gh workflow run ci.yml --ref main -f env=stage` |
| Последние запуски | `gh run list --workflow ci.yml --limit 10` |
| Следить за запуском | `gh run watch <run-id>` |
| Логи упавших шагов | `gh run view <run-id> --log-failed` |
| Перезапустить упавшие джобы | `gh run rerun <run-id> --failed` |
| Статический анализ workflow | `actionlint` (ловит ошибки выражений, `needs`, shellcheck в `run:`) |

## Self-hosted runners

| Вариант | Свойства |
| :--- | :--- |
| GitHub-hosted | чистая VM на джобу, нет доступа в приватную сеть |
| Persistent self-hosted | ⚠️ «грязное» состояние между джобами, риск для публичных репо |
| ARC (Actions Runner Controller) | эфемерный под на джобу, scale-to-zero |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| `test` не видит файлы `build` | разные раннеры → upload/download-artifact |
| `export` из шага 1 пуст в шаге 2 | каждый шаг — отдельный процесс → `$GITHUB_ENV` |
| `Could not load credentials` / ошибка OIDC | нет `id-token: write`, `sub` не совпал с trust policy |
| `checkout` 404 на приватном репо | задан `permissions`, но нет `contents: read` |
| Джоба висит в `Waiting` | Required reviewers в Environment |
| Сборка Docker каждый раз с нуля | нет `cache-from/cache-to` (`gha` или registry) |
| Секреты пустые в PR из форка | так задумано: секреты не передаются в `pull_request` из форков |

> Проверка: `gh` (`workflow run`, `run list/watch/view --log-failed`,
> `rerun --failed`) — `--help`; YAML — `yamllint` и `actionlint` 1.7.7
> на собранном workflow; не проверено: trust policy AWS на реальном
> аккаунте.
