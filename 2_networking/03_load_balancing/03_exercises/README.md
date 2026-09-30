# Упражнения — Балансировка нагрузки

Стенд: 🐳 Tier 1 — Nginx + 3 backend'а в Docker Compose

```bash
cd ../02_examples
docker compose up -d
```

## 01 — least_conn на практике

```bash
for i in $(seq 1 9); do curl -s http://localhost:8090/; done
# TODO: должно получиться ровно по 3 ответа от каждого backend'а
```

## 02 — Health checks: вывод backend'а из ротации

**Задача:** Убить один backend, убедиться что трафик идёт только на оставшиеся, вернуть — снова участвует.

```bash
docker compose stop backend2
for i in $(seq 1 6); do curl -s http://localhost:8090/; done
# TODO: backend2 не должен встречаться в ответах

docker compose start backend2
sleep 11   # fail_timeout=10s в конфиге — нужно ПОЛНОСТЬЮ пережить это окно,
           # 3-4 секунды не хватит, backend2 всё ещё будет исключён из ротации
for i in $(seq 1 6); do curl -s http://localhost:8090/; done
# TODO: backend2 должен снова появиться среди ответов
```

## 03 — Cascading failure через healthcheck-антипаттерн

**Задача:** Понять, как ломается healthcheck, если он проверяет зависимость, а не сам сервис (без реального кода — просто разбери сценарий).

```
# TODO (письменно, без кода): представь, что /healthz каждого backend'а
# сам делает запрос к общей базе данных перед тем как ответить 200.
# База данных легла на 30 секунд. Что произойдёт с балансировщиком?
# Сравни с текущим /healthz (return 200 без всяких проверок) — почему
# он не подвержен этой проблеме?
```

## 04 — Sticky sessions vs stateless backend

```
# TODO (письменно): backend хранит счётчик запросов в переменной процесса
# (не во внешнем сторе). Что произойдёт со счётчиком клиента, если
# балансировщик без sticky sessions раскидывает его запросы по разным backend'ам?
# Как это чинить — sticky sessions или другой архитектурный подход?
```

## 05 — Ловушка: round-robin на низком трафике с несколькими воркерами

**Задача:** Убедиться, что при нескольких worker-процессах распределение перестаёт быть предсказуемым на малом числе запросов.

```bash
# В nginx.conf стоит worker_processes 1 — упражнение 01 поэтому даёт чистое 3/3/3.
# TODO: смени на `worker_processes 4;`, пересоздай контейнер:
docker compose up -d --force-recreate lb
for i in $(seq 1 9); do curl -s http://localhost:8090/; done
# TODO: сравни распределение с упражнением 01 — почему оно больше не 3/3/3?
# Верни worker_processes обратно в 1 после эксперимента.
```
