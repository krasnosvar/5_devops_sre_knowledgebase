# Упражнения — Container Security

Стенд: 🐳 Tier 1 — Docker

## 01 — Drop capabilities и non-root

**Задача:** Запустить nginx без root и с минимальными capabilities.

```bash
# Задача: найти минимальный набор capabilities для nginx
# Подсказка: начни с --cap-drop ALL, добавляй по одному

# Сначала посмотри что нужно nginx по умолчанию
docker run --rm alpine sh -c "cat /proc/1/status | grep Cap"

# TODO: запустить nginx с минимальными правами
docker run -d \
  --cap-drop ALL \
  --cap-add ??? \
  --user 1000:1000 \
  -p 8080:8080 \
  nginx:alpine
```

## 02 — Read-only filesystem

**Задача:** Запустить nginx с `--read-only`. Разобраться почему не запускается. Добавить нужные tmpfs монты.

```bash
# Попробовать запустить (упадёт)
docker run --rm --read-only nginx:alpine

# Посмотреть в какие директории nginx пишет
docker run --rm nginx:alpine sh -c "nginx -T 2>&1 | grep -i path"

# TODO: добавить правильные --tmpfs монты
docker run -d --read-only \
  --tmpfs ??? \
  --tmpfs ??? \
  -p 8080:80 \
  nginx:alpine
```

## 03 — Trivy сканирование

**Задача:** Просканировать три образа разного возраста/размера. Сравнить результаты.

```bash
# Установить trivy
# https://aquasecurity.github.io/trivy/latest/getting-started/installation/

# Просканировать образы
trivy image --severity HIGH,CRITICAL nginx:latest
trivy image --severity HIGH,CRITICAL ubuntu:20.04
trivy image --severity HIGH,CRITICAL alpine:3.18

# Вопросы для анализа:
# - Какой образ самый безопасный?
# - Сколько CRITICAL CVE в ubuntu:20.04?
# - Что лучше для базового образа с точки зрения security?
```

## 04 — Dockerfile hardening

**Задача:** Улучшить небезопасный Dockerfile.

```dockerfile
# bad.Dockerfile — найти и исправить все проблемы (минимум 5)
FROM ubuntu:latest
RUN apt-get update && apt-get install -y python3 pip
ARG DB_PASSWORD=mysecret
ENV DB_PASSWORD=$DB_PASSWORD
COPY . /app
RUN cd /app && pip install -r requirements.txt
EXPOSE 22 80 443 8080 5432
CMD ["python3", "/app/main.py"]
```

```bash
# Проверить hadolint
hadolint bad.Dockerfile

# После исправления — пересканировать trivy
trivy config good.Dockerfile
```
