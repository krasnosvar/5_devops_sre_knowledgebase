# Ответы — упражнения Image layers

Упражнения: [03_exercises/README.md](../03_exercises/README.md).

## Упражнение 01 — Оптимизация кэша слоёв

Исправленный Dockerfile — [Dockerfile.answer](./Dockerfile.answer). Проект:
`app.py` + `requirements.txt` (например, одна строка `flask==3.0.3`) рядом с
Dockerfile.

```bash
cp Dockerfile.answer Dockerfile   # в каталоге с app.py и requirements.txt
time docker build -t myapp:v1 .
# изменить app.py (любая строка)
time docker build -t myapp:v2 .
```

Ожидаемый вывод (примерно так):

```text
real    0m32s          # первая сборка: apt-get, pip install
...
#7 [4/7] COPY requirements.txt .
#7 CACHED
#8 [5/7] RUN pip install --no-cache-dir -r requirements.txt
#8 CACHED
real    0m3s           # вторая сборка: пересобран только COPY . . и следом
```

Почему так: кэш слоя инвалидируется, когда меняется содержимое файлов в его
`COPY` или текст инструкции — и вместе с ним все слои ниже. Пока
`requirements.txt` не менялся, слой `pip install` берётся из кэша; меняется
только слой `COPY . .` с кодом. В исходном варианте `COPY . .` стоял до
`pip install`, и любая правка кода переустанавливала зависимости.

## Упражнение 02 — Multi-stage build

Dockerfile — [Dockerfile.multistage-go](./Dockerfile.multistage-go). Рядом
с ним `main.go` из условия и `go.mod`:

```bash
cat > go.mod <<'EOF'
module example.com/hello

go 1.22
EOF
cp Dockerfile.multistage-go Dockerfile
docker build -t myapp:go .
docker images myapp:go
docker run -d --name myapp-go -p 8080:8080 myapp:go
curl -s http://localhost:8080
docker rm -f myapp-go
```

Ожидаемый вывод (примерно так):

```text
REPOSITORY   TAG   IMAGE ID       CREATED          SIZE
myapp        go    29d837c97398   10 seconds ago   5MB
Hello from minimal container!
```

Почему так: в финальный образ `scratch` попадают только статический бинарник
(`CGO_ENABLED=0` — без зависимости от libc) и CA-сертификаты; компилятор Go
(~250 MB) остаётся в стадии `builder`. `-ldflags="-s -w"` убирает таблицу
символов и DWARF. `go.sum*` в `COPY` — потому что у модуля без внешних
зависимостей файла `go.sum` нет.

## Упражнение 03 — Анализ через dive

```bash
dive nginx:latest
dive nginx:alpine
```

Ожидаемый вывод (примерно так, интерактивный TUI; цифры зависят от версии
образа):

```text
│ Layers ├──────────────────────
Cmp   Size  Command
     75 MB  FROM blobs                  # базовый debian
     ...    RUN ... apt-get install ... nginx
Image efficiency score: 98 %
Total Image size: ~190 MB          (nginx:alpine: ~50 MB)
```

Почему так: больше всего места занимает базовый слой дистрибутива и слой с
установкой пакетов. В окне `Image details` dive показывает «wasted space» —
файлы, которые перезаписаны или удалены в более поздних слоях, но физически
остались в ранних (удаление в отдельном `RUN` размер не уменьшает). Alpine
меньше за счёт musl и минимального набора пакетов.

## Упражнение 04 — .dockerignore

Пример `.dockerignore` — [../02_examples/.dockerignore](../02_examples/.dockerignore).

```bash
mkdir dockerignore-lab && cd dockerignore-lab
git init -q
mkdir -p node_modules/big && head -c 50M /dev/urandom > node_modules/big/blob.bin
head -c 5M /dev/urandom > debug.log
printf 'FROM alpine:3.20\nCOPY . /app\n' > Dockerfile

docker build --no-cache --progress=plain -t ctx:without . 2>&1 | grep 'transferring context'
printf '.git/\nnode_modules/\n*.log\n' > .dockerignore
docker build --no-cache --progress=plain -t ctx:with . 2>&1 | grep 'transferring context'
docker images ctx
```

Ожидаемый вывод (примерно так):

```text
#5 transferring context: 55.07MB 0.4s done
#5 transferring context: 160B 0.0s done
REPOSITORY   TAG       SIZE
ctx          with      8MB
ctx          without   63MB
```

Почему так: без `.dockerignore` клиент отправляет демону весь каталог
(включая `.git/`, `node_modules/`, логи) — сборка медленнее, `COPY . .` тащит
мусор в образ и ломает кэш при каждом изменении в `.git`. Плюс это риск
утечки (`.env`, ключи) внутрь образа.
