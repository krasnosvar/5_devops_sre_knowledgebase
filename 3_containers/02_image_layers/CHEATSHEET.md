# Слои образов и OverlayFS — шпаргалка

Подробности и объяснения — в [image_layers.md](./01_theory/image_layers.md).
⚠️ — опасная команда или частая ловушка.

## Из чего состоит образ

| Часть | Что внутри |
| :--- | :--- |
| Manifest (JSON) | список слоёв (sha256) + ссылка на config |
| Config (JSON) | ENV, CMD, ENTRYPOINT, архитектура, история |
| Layers | tar-архивы (gzip/zstd) — дифф файлов относительно предыдущего слоя |
| `pull` | качает только слои, которых нет в локальном кэше |

## OverlayFS контейнера

| Каталог | Роль |
| :--- | :--- |
| `LowerDir` | read-only слои образа (общие для всех контейнеров) |
| `UpperDir` | writable-слой контейнера, удаляется вместе с ним |
| `MergedDir` | точка монтирования = `/` контейнера |
| `WorkDir` | служебный, для атомарных операций overlay |
| Whiteout | char device 0/0 в `UpperDir` — «файл удалён» |

## Команды

| Задача | Команда |
| :--- | :--- |
| Слои и команды, их создавшие | `docker history <image>` (полностью: `--no-trunc`) |
| Digest'ы слоёв | `docker image inspect -f '{{json .RootFS.Layers}}' <image>` |
| Пути overlay у контейнера | `docker inspect -f '{{json .GraphDriver.Data}}' <c>` |
| Что изменилось в writable-слое | `docker diff <c>` (`A` добавлен, `C` изменён, `D` удалён) |
| Размер writable-слоя | `docker ps -s` |
| Манифест в registry без pull | `docker buildx imagetools inspect <image>` |
| Размеры образов | `docker images --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}'` |
| Сколько места занято / кэш сборки | `docker system df` |
| Почистить кэш сборки ⚠️ | `docker builder prune` |
| Интерактивно по слоям | `dive <image>` |
| Смонтированные overlay на хосте | `findmnt -t overlay` |

## Кэш сборки и multi-stage

```dockerfile
# зависимости до кода: правка кода не сбрасывает кэш npm ci
COPY package.json package-lock.json ./
RUN npm ci
COPY . .

# multi-stage: в финальный образ попадает только бинарник
FROM golang:1.24 AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /app .
FROM scratch
COPY --from=build /app /app
ENTRYPOINT ["/app"]
```

| Правило кэша | Следствие |
| :--- | :--- |
| Изменилась инструкция или checksum файлов `COPY`/`ADD` | пересобирается этот слой и **все** ниже |
| Редко меняемое — выше, часто — ниже | `COPY . .` как можно позже |
| Принудительно без кэша | `docker build --no-cache .` |

## Подвохи

| ⚠️ | Суть |
| :--- | :--- |
| `RUN rm -rf /var/cache/apt/*` отдельной строкой | образ не уменьшится — данные в предыдущем слое; чистить в том же `RUN` через `&&` |
| `RUN chown -R` после `COPY` | CoW копирует файлы ещё раз — используйте `COPY --chown` |
| Запись в большой файл образа | CoW копирует файл целиком в `UpperDir` |
| БД в `UpperDir` | теряется при удалении контейнера и медленная — нужен volume |
| `ADD <url>` | непредсказуемо; по умолчанию `COPY`, `ADD` — только для распаковки tar |
| 10 контейнеров из образа 1 GB | на диске ≈ 1 GB: слои общие |

> Проверка: команды и `--format`-шаблоны выполнены локально (Docker
> 29.9, buildx 0.38); не проверено: `dive` (нет на хосте).
