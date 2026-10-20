# GitOps глазами CI — шпаргалка

Подробности и объяснения — в [gitops_cd.md](./01_theory/gitops_cd.md).
Агенты ArgoCD/Flux — в [4_kubernetes/09_gitops](../../4_kubernetes/09_gitops/).
⚠️ — опасная команда или частая ловушка.

## Push vs Pull для пайплайна

| | Push (CI деплоит) | Pull (GitOps) |
| :--- | :--- | :--- |
| Права CI | kubeconfig / облачная роль на прод | токен на запись в один Ops-репо |
| Зелёная джоба значит | раскатка прошла (`kubectl rollout status`) | коммит в Git сделан |
| Повтор джобы | передеплой | ничего, если тег не изменился |
| Откат | новая джоба деплоя | `git revert` в Ops-репо |

## Обновить тег образа из CI

| Задача | Команда |
| :--- | :--- |
| Тег в Kustomize overlay | `cd envs/dev && kustomize edit set image app=registry.example.com/app:3f2c1a9` |
| Закрепить digest | `kustomize edit set image app=registry.example.com/app@sha256:<digest>` |
| Тег в Helm values | `yq -i '.image.tag = "3f2c1a9"' envs/dev/values.yaml` |
| Нечего коммитить? | `git diff --quiet && echo "already up to date"` |
| Push с повтором при гонке | `git pull --rebase origin main && git push origin HEAD:main` (ограниченное число попыток) |
| Сериализовать пуши | GitLab `resource_group: ops-repo-dev`, GitHub `concurrency: ops-repo-dev` |
| Создать MR в GitLab | `curl --fail -X POST -H "PRIVATE-TOKEN: $OPS_REPO_TOKEN" --data-urlencode source_branch=$B --data-urlencode target_branch=main --data-urlencode "title=Promote ..." "$CI_API_V4_URL/projects/$OPS_REPO_ID/merge_requests"` |
| Создать PR в GitHub | `gh pr create --base main --head "$B" --title "Promote ..." --body "..."` |

Полный рабочий пример —
[.gitlab-ci-gitops.yml](./02_examples/.gitlab-ci-gitops.yml).

## Promotion dev → stage → prod

| Среда | Как попадает версия | Аппрув |
| :--- | :--- | :--- |
| dev | CI коммитит тег прямо в `envs/dev` | нет |
| stage | MR переносит тот же тег в `envs/stage` | ревью MR |
| prod | отдельный MR в `envs/prod` | protected branch + обязательные ревьюеры |

| Паттерн | Вердикт |
| :--- | :--- |
| Папки окружений в одной ветке (`envs/dev`, `envs/stage`, `envs/prod`) | предпочтительно |
| Ветка на окружение (`dev`/`stage`/`prod`) | хуже: окружения расходятся, мержи тянут лишнее |
| Тот же App-репо для манифестов | ⚠️ коммит бота снова запускает CI (цикл) |

## Узнать результат раскатки

| Задача | Команда |
| :--- | :--- |
| Дождаться ArgoCD | `argocd app wait myapp-dev --sync --health --timeout 300` |
| Статус приложения ArgoCD | `argocd app get myapp-dev` |
| События Flux | `flux events --for Kustomization/myapp-dev` |
| Принудительно сверить Flux | `flux reconcile kustomization myapp-dev --with-source` |
| Обратный канал без доступа к кластеру | ArgoCD Notifications / Flux notification-controller → commit status |

## Чем обновлять тег

| Способ | Плюсы | Минусы |
| :--- | :--- | :--- |
| CI коммитит в Ops-репо | явная связь «коммит кода → релиз» | скрипты, гонки, токен в CI |
| ArgoCD Image Updater / Flux Image Automation | CI только пушит образ | контроллеру нужен write в Git, задержка опроса registry |

## Токен CI для Ops-репо

| Правило | Как |
| :--- | :--- |
| Не личный | Project Access Token / deploy key / fine-grained PAT |
| Минимальный scope | `write_repository` (+ `api`, если CI создаёт MR) |
| Только на защищённых ветках | переменная Masked + Protected |
| prod не мержится ботом | protected branch, бот только создаёт MR |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| `rejected (non-fast-forward)` | параллельные пуши → `pull --rebase` + повтор, `resource_group`/`concurrency` |
| Джоба зелёная, dev не обновился | путь/ветка агента (`path`, `targetRevision`), интервал опроса/webhook, `OutOfSync`/`Degraded` |
| Тег в манифесте не поменялся | имя в `kustomize edit set image` ≠ `images[].name` — молча не применяется |
| `nothing to commit` | тег уже стоит — проверять `git diff --quiet` |
| Ручной `kubectl set image` откатился через минуты | ⚠️ self-heal вернул состояние из Git → `git revert` в Ops-репо |
| Под не обновился на `latest` | ⚠️ Git не изменился + `IfNotPresent` → неизменяемые теги/digest |

> Проверка: `kustomize edit set image`, `argocd app wait/get` (3.1.8),
> `flux events/reconcile` (2.6.4), `gh pr create` — по `--help`;
> `kustomize edit set image` и `yq -i` (v4) прогнаны на файлах в scratch;
> не проверено: GitLab MR API на живом инстансе.
