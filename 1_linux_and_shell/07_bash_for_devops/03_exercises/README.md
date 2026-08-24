# Упражнения — Bash for DevOps

Все упражнения — самостоятельные bash скрипты с автопроверкой.

## 01 — Idempotent setup script

**Задача:** Написать скрипт `setup.sh` который:
- Создаёт директорию `/opt/myapp/` если не существует
- Добавляет строку в `/etc/hosts` если не существует
- Устанавливает пакет если не установлен
- Можно запустить несколько раз без ошибок

```bash
#!/usr/bin/env bash
set -euo pipefail

# TODO: реализовать

# Проверка идемпотентности:
./setup.sh  # первый запуск — применить изменения
./setup.sh  # второй запуск — "already done", без ошибок
```

## 02 — Retry с backoff

**Задача:** Написать функцию `retry` и использовать её для ожидания пока HTTP сервис станет доступен.

```bash
# TODO: retry 5 2 curl -sf http://localhost:8080/health
# Ожидаемое поведение:
# Attempt 1/5 failed, retrying in 2s...
# Attempt 2/5 failed, retrying in 4s...
# Attempt 3/5 succeeded
```

## 03 — JSON обработка через jq

**Задача:** Дан вывод `kubectl get pods -o json`. Написать однострочники:
1. Вывести имена всех pods в статусе Running
2. Вывести pod с наибольшим количеством restart'ов
3. Сформировать CSV: name,namespace,status,restarts

```bash
# Использовать тестовые данные:
kubectl get pods -A -o json > test-pods.json
# или
curl -s https://... > test-pods.json

# TODO: написать jq выражения
cat test-pods.json | jq '...'
```

## 04 — Мониторинг диска и алерт

**Задача:** Написать скрипт который:
- Проверяет использование дисков каждые 30 секунд
- При превышении 80% — пишет в лог с timestamp
- Запускается через trap при получении SIGTERM
- Использует lockfile чтобы не запускаться дважды

## 05 — Параллельный деплой

**Задача:** Написать скрипт который параллельно выполняет `ssh server "systemctl restart nginx"` на списке серверов из файла `servers.txt`, максимум 3 параллельно, собирает результаты.
