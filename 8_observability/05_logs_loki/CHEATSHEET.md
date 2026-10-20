# Loki и LogQL — шпаргалка

Подробности и объяснения — в [01_theory/](./01_theory/). ⚠️ — опасная
команда или частая ловушка.

## Метки: что можно, что нельзя

Подробно: [01_loki.md](./01_theory/01_loki.md),
[02_loki_logql.md](./01_theory/02_loki_logql.md).

| Хорошие метки (мало значений) | Плохие метки ⚠️ (cardinality → OOM) |
| :--- | :--- |
| `env`, `cluster`, `namespace`, `app`, `container` | `user_id`, `request_id`, `trace_id`, IP, `path` с ID |
| `level` (5–6 значений) | `status` + `path` + `pod` одновременно на всё |

Метки — чтобы выбрать stream, текст — фильтровать pipeline'ом:
`{app="web"} |= "trace_id=abc123"`.

## Селектор потока

| Задача | LogQL |
| :--- | :--- |
| Одно приложение | `{app="nginx"}` |
| Несколько меток | `{namespace="production", app="api"}` |
| Regex по метке | `{app=~"api\|worker"}` |
| Исключить значение второй меткой | `{app="api", env!="dev"}` |
| «Все потоки» | `{app=~".+"}` ⚠️ `{}` и `{app=~".*"}` Loki отвергает |

## Pipeline: фильтры и парсеры

| Задача | LogQL |
| :--- | :--- |
| Содержит / не содержит | `\|= "error"` / `!= "health"` |
| Regex / не regex | `\|~ "5[0-9]{2}"` / `!~ "GET /api/health"` |
| Без учёта регистра | `\|~ "(?i)error"` |
| Цепочка фильтров | `{app="api"} \|= "error" != "timeout"` |
| JSON → поля | `\| json` |
| Только нужные поля JSON | `\| json level, status` |
| logfmt | `\| logfmt` |
| Шаблон access-лога | `` \| pattern `<ip> - <_> [<ts>] "<method> <path> <_>" <status> <size>` `` |
| Regex с именованными группами | `` \| regexp `(?P<method>GET\|POST) (?P<path>/\S*)` `` |
| Фильтр по извлечённому полю | `\| json \| level="error"` |
| Числа, длительности, размеры | `\| status >= 500`, `\| duration > 1s`, `\| size > 10KB` |
| Переформатировать строку | `` \| line_format "{{.level}} {{.message}}" `` |
| Убрать/оставить метки | `\| drop pod` / `\| keep app, level` |
| Отладить парсинг | смотреть метки `__error__`; убрать ошибки: `\| __error__=""` |

⚠️ Сначала текстовые фильтры (`|=`), потом парсер: фильтр до `| json`
режет объём, который парсится.

## Метрики из логов

| Задача | LogQL |
| :--- | :--- |
| Строк за минуту | `count_over_time({app="api"} \|= "error" [1m])` |
| Строк в секунду по app | `sum by (app) (rate({namespace="production"} \|= "error" [5m]))` |
| Байт в секунду | `sum by (app) (bytes_rate({namespace="production"}[5m]))` |
| 404 по path | `sum by (path) (count_over_time({app="nginx"} \| json \| status="404" [5m]))` |
| p95 из поля | `quantile_over_time(0.95, {app="api"} \| json \| unwrap duration_ms [5m]) by (endpoint)` |
| Среднее из поля | `avg_over_time({app="api"} \| json \| unwrap duration_ms [5m]) by (endpoint)` |
| Длительность «250ms» → секунды | `\| logfmt \| unwrap duration(duration)` |
| Топ-5 медленных endpoint'ов | `topk(5, avg_over_time({app="api"} \| json \| unwrap duration_ms [5m]) by (endpoint))` |

⚠️ После `unwrap` работают только `*_over_time` (`sum_over_time`,
`avg_over_time`, `max_over_time`, `quantile_over_time`, `rate`); голый
`avg by (...)` поверх строк не применим.

## logcli

| Задача | Команда |
| :--- | :--- |
| Адрес / tenant | `export LOKI_ADDR=http://localhost:3100`, `--org-id=team-a` |
| Логи за последний час | `logcli query '{app="api"} \|= "error"'` |
| За 6 часов, до 500 строк, только текст | `logcli query --since=6h --limit=500 -o raw '{app="api"}'` |
| Хвост в реальном времени | `logcli query --tail '{app="api"}'` |
| Метрический запрос в момент времени | `logcli instant-query 'sum by (app) (rate({namespace="production"}[5m]))'` |
| Какие метки / значения есть | `logcli labels` / `logcli labels app` |
| Потоки и кардинальность меток | `logcli series '{namespace="production"}' --analyze-labels` |
| Объём данных под запрос | `logcli stats '{app="api"}'` |
| Выгрузка большого интервала параллельно | `logcli query --from=... --to=... --parallel-duration=15m --parallel-max-workers=4 --part-path-prefix=/tmp/q --merge-parts '{app="api"}'` |

## HTTP API

| Задача | Команда |
| :--- | :--- |
| Готовность | `curl -s localhost:3100/ready` |
| Записать строку | `curl -H 'Content-Type: application/json' -X POST localhost:3100/loki/api/v1/push -d '{"streams":[{"stream":{"app":"t"},"values":[["'$(date +%s%N)'","hello"]]}]}'` |
| Запрос диапазона | `curl -sG localhost:3100/loki/api/v1/query_range --data-urlencode 'query={app="t"}'` |
| Мультитенантность | заголовок `X-Scope-OrgID: team-a` |

## Alloy (агент)

| Задача | Команда / компонент |
| :--- | :--- |
| Проверить и отформатировать конфиг | `alloy fmt config.alloy` (`-w` — на месте, `-t` — для CI) |
| Запуск | `alloy run config.alloy` (UI и граф компонентов — `:12345`) |
| UI недоступен из контейнера ⚠️ | дефолт `127.0.0.1:12345`: `alloy run --server.http.listen-addr=0.0.0.0:12345 ...` |
| Перевести конфиг Promtail ⚠️ Promtail EOL | `alloy convert --source-format=promtail --output=config.alloy promtail-config.yaml` |
| Поды k8s через API | `discovery.kubernetes` → `discovery.relabel` → `loki.source.kubernetes` |
| Файлы / Docker / journald | `loki.source.file`, `loki.source.docker`, `loki.source.journal` |
| Парсинг и метки на агенте | `loki.process` со `stage.json`, `stage.labels`, `stage.drop` |
| Отправка | `loki.write "default" { endpoint { url = "http://loki:3100/loki/api/v1/push" } }` |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| Запрос идёт минуты / таймаут | сузить время, добавить меток в селектор, `logcli stats` |
| Loki OOM, `stream limit exceeded` | высококардинальная метка (`logcli series --analyze-labels`) |
| `entry too far behind` / `out of order` | часы на агенте, ретраи старых батчей |
| Пустой результат после `\| json` | поле вложено: `\| json nested="a.b"`; проверить `__error__` |
| Агент не шлёт логи | UI Alloy `:12345`, health компонентов; доступ к `/var/log/pods` или к API |
| Логи пропали при падении ingester | WAL ingester'а, replication factor |

> Проверка: все запросы LogQL из таблиц и команды logcli прогнаны
> против grafana/loki (3.7.8) с logcli 3.5.0 на тестовых потоках;
> `alloy fmt`/`alloy convert --help` — grafana/alloy:v1.10.0;
> не проверено: `--parallel-*` выгрузка на реальном объёме.
