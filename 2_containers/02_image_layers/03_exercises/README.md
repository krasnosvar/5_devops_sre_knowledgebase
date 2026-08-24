# Упражнения — Image layers

Стенд: 🐳 Tier 1 — Docker

## 01 — Оптимизация кэша слоёв

**Задача:** Дан Dockerfile с плохим порядком инструкций. Переписать чтобы pip install кэшировался при изменении кода (но не зависимостей).

```dockerfile
# bad-dockerfile (переписать!)
FROM python:3.12-slim
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
CMD ["python", "app.py"]
```

Проверка:
```bash
# Изменить app.py
docker build -t myapp:v1 .  # замерить время
docker build -t myapp:v2 .  # должно быть быстрее (кэш pip)
```

## 02 — Multi-stage build

**Задача:** Написать multi-stage Dockerfile для Go приложения. Итоговый образ должен быть < 20 MB (использовать `scratch` или `distroless`).

```go
// main.go
package main
import (
    "fmt"
    "net/http"
)
func main() {
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintln(w, "Hello from minimal container!")
    })
    http.ListenAndServe(":8080", nil)
}
```

```bash
docker build -t myapp:go .
docker images myapp:go  # должен быть < 20 MB
docker run -p 8080:8080 myapp:go
```

## 03 — Анализ через dive

```bash
# Установить dive
# https://github.com/wagoodman/dive

dive nginx:latest
# Найти: какой слой занимает больше всего места?
# Найти: есть ли файлы которые можно удалить?

# Сравнить образы
dive nginx:alpine  # vs
dive nginx:latest
```

## 04 — .dockerignore

**Задача:** Создать проект с `.git/`, `node_modules/`, `*.log` файлами. Собрать образ без `.dockerignore` и с `.dockerignore`. Сравнить размер context и образа.
