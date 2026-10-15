# Ответы — Bash for DevOps

Упражнения 01, 02, 04 и 05 просят написать скрипт, поэтому ответ — готовый
`.sh` рядом с этим файлом; здесь — как его запустить, что увидеть и почему
он устроен именно так. Упражнение 03 — набор jq-однострочников. Выводы
приблизительные.

## Упражнение 01 — Idempotent setup script

Скрипт: [01_idempotent_setup.sh](./01_idempotent_setup.sh).

```bash
# Удобнее всего проверять в одноразовом контейнере
docker run --rm -it -v "$PWD":/a:ro ubuntu:24.04 bash
bash /a/01_idempotent_setup.sh
bash /a/01_idempotent_setup.sh
tail -1 /etc/hosts
```

Ожидаемый вывод (примерно так):

```text
[11:53:01] /opt/myapp: created
[11:53:01] /etc/hosts entry: added
[11:53:05] jq: installed (apt)
[11:53:05] Setup complete — safe to run multiple times
[11:53:06] /opt/myapp: already done
[11:53:06] /etc/hosts entry: already done
[11:53:06] jq: already done
[11:53:06] Setup complete — safe to run multiple times
10.0.0.10 myapp.internal
```

Почему так: каждое действие начинается с проверки текущего состояния
(«есть ли директория/строка/бинарник»), а не с действия. `grep -qxF`
сравнивает строку целиком и без regex — иначе точка в IP совпала бы с
любым символом. Неизвестный пакетный менеджер — явная ошибка, а не тихий
пропуск.

## Упражнение 02 — Retry с backoff

Скрипт: [02_retry_with_backoff.sh](./02_retry_with_backoff.sh).

```bash
# Терминал 1: поднять сервис секунд через 5
sleep 5; mkdir -p /tmp/www && touch /tmp/www/health \
  && python3 -m http.server 8080 -d /tmp/www

# Терминал 2
bash 02_retry_with_backoff.sh http://localhost:8080/health; echo "rc=$?"
bash 02_retry_with_backoff.sh http://localhost:9/nothing; echo "rc=$?"
```

Ожидаемый вывод (примерно так):

```text
Attempt 1/5 failed, retrying in 2s...
Attempt 2/5 failed, retrying in 4s...
Attempt 3/5 succeeded
Service http://localhost:8080/health is up
rc=0
...
Attempt 4/5 failed, retrying in 16s...
Attempt 5/5 failed, giving up: curl -sf --max-time 3 -o /dev/null http://...
rc=1
```

Почему так: команда передаётся как `"$@"`, поэтому аргументы с пробелами не
ломаются. Задержка удваивается с потолком 60 с, а после последней попытки
функция возвращает 1 — вызывающий код (и `set -e`) видит провал. `curl -f`
обязателен: без него HTTP 500 считается успехом.

## Упражнение 03 — JSON обработка через jq

Данные: [../03_exercises/test-pods.json](../03_exercises/test-pods.json).

```bash
cd ../03_exercises

# 1. Имена pods в статусе Running
jq -r '.items[] | select(.status.phase == "Running") | .metadata.name' \
  test-pods.json

# 2. Pod с наибольшим числом рестартов (сумма по всем контейнерам)
jq -r '.items
  | max_by([.status.containerStatuses[]?.restartCount] | add // 0)
  | "\(.metadata.name) \([.status.containerStatuses[]?.restartCount] | add // 0)"' \
  test-pods.json

# 3. CSV: name,namespace,status,restarts
jq -r '["name","namespace","status","restarts"],
  (.items[] | [.metadata.name, .metadata.namespace, .status.phase,
    ([.status.containerStatuses[]?.restartCount] | add // 0)])
  | @csv' test-pods.json
```

Ожидаемый вывод:

```text
api-7d9f8b6c4-x2k8p
worker-5c8d7f9b8-q7m4n
worker-5c8d7f9b8-q7m4n 8
"name","namespace","status","restarts"
"api-7d9f8b6c4-x2k8p","prod","Running",0
"worker-5c8d7f9b8-q7m4n","prod","Running",8
"migrate-29371","prod","Failed",2
"coredns-76f75df574-9wz2c","kube-system","Pending",0
```

Почему так: у Pending-пода ещё нет `containerStatuses` — `[]?` не падает на
отсутствующем поле, а `add // 0` превращает пустую сумму (`null`) в 0.
Рестарты считаются по всем контейнерам пода, а не только по первому.
`@csv` сам расставляет кавычки и экранирует запятые внутри значений.

## Упражнение 04 — Мониторинг диска и алерт

Скрипт: [04_disk_monitor.sh](./04_disk_monitor.sh).

```bash
# Порог 0%, чтобы алерт сработал сразу; период 2 с для наглядности
THRESHOLD=0 INTERVAL=2 bash 04_disk_monitor.sh ./disk.log &
PID=$!
bash 04_disk_monitor.sh ./disk.log; echo "second instance rc=$?"
sleep 3
kill -TERM $PID; wait $PID; echo "rc=$?"
cat disk.log
```

Ожидаемый вывод (примерно так):

```text
ERROR: уже запущен другой экземпляр (lock: /tmp/disk_monitor.lock)
second instance rc=1
rc=0
2026-10-14T15:54:26+0400 INFO started, pid=600984, threshold=0%, interval=2s
2026-10-14T15:54:26+0400 ALERT / usage 65% > 0%
2026-10-14T15:54:26+0400 ALERT /boot usage 49% > 0%
2026-10-14T15:54:28+0400 ALERT / usage 65% > 0%
2026-10-14T15:54:28+0400 ALERT /boot usage 49% > 0%
2026-10-14T15:54:29+0400 INFO stopped by signal, pid=600984
```

Почему так: `flock` на открытом fd надёжнее проверки «существует ли файл» —
блокировку снимает ядро при смерти процесса. `sleep` запускается в фоне и
ожидается через `wait`, потому что bash выполняет trap только между
командами: с обычным `sleep 30` реакция на SIGTERM ждала бы до 30 с.

## Упражнение 05 — Параллельный деплой

Скрипт: [05_parallel_deploy.sh](./05_parallel_deploy.sh).

```bash
printf 'web1\nweb2\nweb3\nweb4\nweb5\n' > servers.txt
bash 05_parallel_deploy.sh servers.txt; echo "rc=$?"
```

Ожидаемый вывод (примерно так, если web3 недоступен):

```text
Restarting nginx on 5 servers, max 3 parallel
OK     web1
OK     web2
FAILED web3 (exit 255): ssh: connect to host web3 port 22: Connection timed out
OK     web4
OK     web5
Done: 4 ok, 1 failed
rc=1
```

Почему так: `wait -n` ждёт завершения любой одной фоновой задачи, так что
одновременно работают не больше трёх `ssh`. Каждая задача пишет вывод и
код возврата в свой файл — параллельный stdout не перемешивается, а итог
собирается после общего `wait`. `ssh -n` не даёт фоновым задачам читать
stdin, `BatchMode=yes` — зависнуть на запросе пароля. Ненулевой код выхода
скрипта при любом провале позволяет использовать его в CI.
