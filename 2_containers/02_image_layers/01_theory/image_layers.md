# Image layers и overlay FS

## Как устроен образ

Docker/OCI образ — это стек read-only слоёв (tar архивов) плюс метаданные.

```
┌─────────────────────────────┐  ← Container layer (read-write, временный)
├─────────────────────────────┤  ← COPY . /app  (слой 4)
├─────────────────────────────┤  ← RUN pip install  (слой 3)
├─────────────────────────────┤  ← COPY requirements.txt  (слой 2)
├─────────────────────────────┤  ← python:3.12-slim (базовый образ, слой 1)
└─────────────────────────────┘
```

Каждая инструкция `RUN`, `COPY`, `ADD` создаёт новый слой.
`ENV`, `EXPOSE`, `CMD`, `LABEL` — изменяют только метаданные, не создают слои.

## overlay FS (overlayfs)

overlayfs — тип ФС в ядре Linux, объединяет несколько директорий в одну.

```
upperdir  (read-write, container layer)
lowerdir  (read-only, image layers, от верхнего к нижнему)
workdir   (служебный, для атомарных операций)
merged    (то, что видит контейнер — union из всех)
```

**Copy-on-write**: при изменении файла из lowerdir:
1. Файл копируется в upperdir
2. Изменения применяются к копии в upperdir
3. overlayfs показывает версию из upperdir (скрывает нижнюю)

```bash
# посмотреть overlay mounts
mount | grep overlay
# или
cat /proc/mounts | grep overlay

# пример вывода:
# overlay on /var/lib/docker/overlay2/abc123/merged type overlay
#   (lowerdir=/var/lib/docker/overlay2/layer1:layer2,
#    upperdir=/var/lib/docker/overlay2/abc123/diff,
#    workdir=/var/lib/docker/overlay2/abc123/work)
```

## Кэш слоёв — как работает и почему важен

Docker кэширует каждый слой по его содержимому (content hash).
При повторной сборке если содержимое не изменилось — слой берётся из кэша.

**Инвалидация кэша** — если слой изменился, все последующие слои
пересобираются заново (даже если их содержимое не менялось).

```dockerfile
# Плохо: COPY . инвалидирует кэш при любом изменении кода
# RUN pip install пересобирается каждый раз
FROM python:3.12-slim
COPY . /app
RUN pip install -r /app/requirements.txt

# Хорошо: зависимости меняются редко → кэшируются отдельно
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .          # меняется редко
RUN pip install -r requirements.txt  # кэшируется пока requirements.txt не изменится
COPY . .                         # меняется часто, но pip install уже в кэше
```

## Multi-stage builds — минимальный итоговый образ

```dockerfile
# Stage 1: build (большой образ с компилятором)
FROM golang:1.22 AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o myapp .

# Stage 2: runtime (минимальный образ)
FROM scratch              # пустой образ, только наш бинарник
# или: FROM gcr.io/distroless/static  # Google distroless
COPY --from=builder /app/myapp /myapp
EXPOSE 8080
ENTRYPOINT ["/myapp"]
```

Результат: образ 10–20 MB вместо 800 MB с Go toolchain.

## Минимизация размера образа

```dockerfile
# Объединять RUN команды → меньше слоёв, apt cache не попадает в образ
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       curl \
       ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Использовать -slim или -alpine варианты базовых образов
FROM python:3.12-slim    # ~100 MB vs 1 GB для python:3.12
FROM node:20-alpine      # ~180 MB vs 1 GB для node:20
```

## .dockerignore — что не копировать

```
# .dockerignore
.git/
.gitignore
**/*.md
**/__pycache__/
**/.pytest_cache/
node_modules/
.env
*.log
dist/
```

Без `.dockerignore` каждый `COPY . .` копирует весь `.git/` в образ
→ большой размер образа и инвалидация кэша при каждом коммите.

## Инспекция образов

```bash
# посмотреть слои и команды которые их создали
docker history nginx:alpine
docker image inspect nginx:alpine | jq '.[0].RootFS.Layers'

# dive — интерактивный просмотр слоёв
# https://github.com/wagoodman/dive
dive nginx:alpine

# размер образа
docker images nginx
docker system df          # общий размер images, containers, volumes
```
