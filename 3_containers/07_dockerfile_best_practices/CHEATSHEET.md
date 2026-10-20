# Dockerfile: лучшие практики — шпаргалка

Подробности и объяснения — в
[dockerfile_best_practices.md](./01_theory/dockerfile_best_practices.md).
Слои и кэш — в [02_image_layers](../02_image_layers/CHEATSHEET.md).
⚠️ — опасная команда или частая ловушка.

## Shell form vs exec form

| | Shell form | Exec form |
| :--- | :--- | :--- |
| Запись | `CMD node server.js` | `CMD ["node", "server.js"]` |
| Что запускается | `/bin/sh -c "..."` → `sh` может стать PID 1 | `execve` напрямую, приложение = PID 1 |
| `$VAR` | раскрывает shell | не раскрывается (shell нет) |
| SIGTERM приложению | может не дойти → SIGKILL через grace period | доходит |
| Когда | `RUN` с пайпами и `&&` | `CMD` и `ENTRYPOINT` — всегда |

## ENTRYPOINT + CMD

| Dockerfile | `docker run img` | `docker run img bash` |
| :--- | :--- | :--- |
| `CMD ["postgres"]` | `postgres` | `bash` |
| `ENTRYPOINT ["entry.sh"]` + `CMD ["postgres"]` | `entry.sh postgres` | `entry.sh bash` |
| Заменить ENTRYPOINT | — | `docker run --entrypoint sh img` |

```bash
#!/bin/sh
# docker-entrypoint.sh: init, затем exec — PID 1 переходит к приложению
set -e
chown -R app:app /data
exec "$@"
```

## PID 1 и сигналы

| Задача | Как |
| :--- | :--- |
| init в образе (сигналы + сбор зомби) | `ENTRYPOINT ["tini", "--", "node", "server.js"]` |
| init без правки образа | `docker run --init img` |
| Переменная в exec form | `ENTRYPOINT ["sh", "-c", "exec node server.js --port $PORT"]` |
| Grace period в Kubernetes | `terminationGracePeriodSeconds` (default 30 с) |
| Кто PID 1 в контейнере | `docker top <c>` / `docker exec <c> cat /proc/1/cmdline` |

## BuildKit: секреты и кэш

| Задача | Dockerfile | Сборка |
| :--- | :--- | :--- |
| Секрет только на время `RUN` | `RUN --mount=type=secret,id=aws_creds cat /run/secrets/aws_creds` | `docker build --secret id=aws_creds,src=$HOME/.aws/credentials .` |
| SSH-агент для `git clone` | `RUN --mount=type=ssh git clone git@github.com:org/repo.git` | `docker build --ssh default .` |
| Кэш пакетного менеджера | `RUN --mount=type=cache,target=/root/.npm npm ci` | — |
| Файлы с владельцем без лишнего слоя | `COPY --chown=app:app . /app` | — |
| Подробный лог сборки | — | `docker build --progress=plain .` |
| Сборка конкретной стадии | — | `docker build --target build .` |
| Мультиархитектура | — | `docker buildx build --platform linux/amd64,linux/arm64 .` |

## Каркас

```dockerfile
# syntax=docker/dockerfile:1
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --omit=dev

FROM node:22-alpine
WORKDIR /app
RUN apk add --no-cache tini
COPY --from=deps --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node . .
USER node
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "server.js"]
```

## .dockerignore

```text
.git
node_modules
venv
*.log
.env
```

## Линт и проверка

| Задача | Команда |
| :--- | :--- |
| Линт Dockerfile | `docker run --rm -i hadolint/hadolint < Dockerfile` |
| Встроенные проверки BuildKit | `docker build --check .` |
| Размер контекста | `docker build --progress=plain . 2>&1 \| grep 'transferring context'` |
| История слоёв | `docker history <image>` |

## Подвохи

| ⚠️ | Суть |
| :--- | :--- |
| `COPY id_rsa` / `ARG TOKEN` | остаются в слоях и `docker history` — только `--mount=type=secret/ssh` |
| `FROM ubuntu:latest` | невоспроизводимо: фиксируйте тег или `@sha256:` |
| Entrypoint-скрипт без `exec "$@"` | скрипт остаётся PID 1, SIGTERM не доходит до приложения |
| `ENTRYPOINT ["echo", "$VAR"]` | печатает `$VAR` буквально: exec form не раскрывает переменные |
| Нет `.dockerignore` | `.git` и `node_modules` уезжают в контекст сборки |
| `RUN chown -R` после `COPY` | удваивает размер — `COPY --chown` |

> Проверка: каркас собран `docker build --check` и `docker build`
> (BuildKit, Docker 29.9) в scratch, флаги `--secret`/`--ssh`/`--init`/
> `--target`/`--check` сверены с `--help`, hadolint запущен в
> контейнере; не проверено: `--platform` мультиархитектурная сборка.
