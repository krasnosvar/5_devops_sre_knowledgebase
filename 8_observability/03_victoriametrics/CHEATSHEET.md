# VictoriaMetrics — шпаргалка

Подробности и объяснения — в
[victoriametrics.md](./01_theory/victoriametrics.md). ⚠️ — опасная
команда или частая ловушка.

## Когда что использовать

| Ситуация | Выбор |
| :--- | :--- |
| Один Prometheus упирается в RAM/диск, нужна история за год | VM single-node |
| Миллионы активных рядов, нужна горизонтальная запись/чтение | VM cluster |
| Десятки k8s-кластеров, центральное хранилище | vmagent в каждом кластере → `remote_write` в центр |
| Уже есть Prometheus, нужен глобальный query + S3 | Thanos / Mimir (см. [09_observability_at_scale](../09_observability_at_scale/)) |
| Алерты и recording rules поверх VM | vmalert → Alertmanager |

## Компоненты и порты

| Компонент | Роль | Порт |
| :--- | :--- | :--- |
| `victoria-metrics` (single) | запись + хранение + PromQL | 8428 |
| `vmagent` | scrape + `remote_write`, дисковый буфер | 8429 |
| `vmalert` | правила (alert/record) по расписанию | 8880 |
| `vminsert` (cluster) | stateless, шардирует ряды по vmstorage | 8480 |
| `vmselect` (cluster) | запросы: опрос всех vmstorage + merge | 8481 |
| `vmstorage` (cluster) | stateful хранение | 8482 (http), 8400 (insert), 8401 (select) |

## URL-ы

| Задача | URL |
| :--- | :--- |
| Запись Prometheus remote_write (single) | `http://vm:8428/api/v1/write` |
| Запись в кластер, tenant 1 | `http://vminsert:8480/insert/1/prometheus/api/v1/write` |
| Datasource Grafana (single) | `http://vm:8428` (тип Prometheus) |
| Datasource Grafana (кластер, tenant 1) | `http://vmselect:8481/select/1/prometheus` |
| Запрос | `curl -sG http://vm:8428/api/v1/query --data-urlencode 'query=up'` |
| Кардинальность (топ метрик/лейблов) | `curl -s http://vm:8428/api/v1/status/tsdb \| jq` |
| Экспорт рядов (JSON lines) | `curl -sG http://vm:8428/api/v1/export -d 'match[]=up'` |
| Удалить ряды ⚠️ | `curl -sG http://vm:8428/api/v1/admin/tsdb/delete_series -d 'match[]={job="old"}'` |
| UI (VMUI, cardinality explorer) | `http://vm:8428/vmui` |

## Флаги

| Компонент | Флаг | Смысл |
| :--- | :--- | :--- |
| single / vmstorage | `-retentionPeriod=90d` | хранение; без суффикса — месяцы (дефолт `1` = 1 месяц) |
| single / vmstorage | `-storageDataPath=/victoria-metrics-data` | каталог данных |
| single / vmstorage | `-storage.maxHourlySeries=N` / `-storage.maxDailySeries=N` | лимит новых рядов — предохранитель от cardinality |
| single / vmselect | `-dedup.minScrapeInterval=30s` | дедупликация HA-пары scrape'еров |
| vminsert | `-replicationFactor=2` | каждая точка на 2 vmstorage |
| vmagent | `-promscrape.config=scrape.yml` | Prometheus-совместимый scrape-конфиг |
| vmagent | `-remoteWrite.url=...` | можно несколько раз — запись в несколько мест |
| vmagent | `-remoteWrite.tmpDataPath=/vmagentdata` | дисковая очередь при недоступности получателя |
| vmagent | `-remoteWrite.maxDiskUsagePerURL=10GB` | ⚠️ без лимита очередь съест диск |
| vmagent | `-promscrape.config=scrape.yml -dryRun` | проверить конфиг и выйти |
| vmalert | `-rule=/etc/rules/*.yml -datasource.url=http://vm:8428 -notifier.url=http://alertmanager:9093` | минимальный запуск |
| vmalert | `-remoteWrite.url=http://vm:8428` / `-remoteRead.url=...` | куда писать recording rules / восстановить состояние алертов |
| vmalert | `-dryRun -rule=rules.yml` | проверить правила без запуска |

## MetricsQL vs PromQL

| Отличие | MetricsQL |
| :--- | :--- |
| `rate()`/`increase()` | без экстраполяции: `increase` целого counter даёт целое |
| Окно можно не писать | `rate(http_requests_total)` — окно = step графика |
| Шаблоны | `WITH (f = {job="api"}) rate(http_requests_total{f}[5m])` |
| Значение по умолчанию | `q default 0` |
| Сохранить имя метрики после функции | `rate(x[5m]) keep_metric_names` |
| Утилизация ресурса | `ru(free, max)` |

⚠️ Графики `rate()` из VM и Prometheus по одним данным могут слегка
отличаться — это разница в экстраполяции, не ошибка.

## Бэкап

| Задача | Команда |
| :--- | :--- |
| Снапшот | `curl http://vm:8428/snapshot/create` |
| Бэкап в S3 | `vmbackup -storageDataPath=/victoria-metrics-data -snapshot.createURL=http://vm:8428/snapshot/create -dst=s3://bucket/vm/daily` |
| Восстановление ⚠️ (VM остановлена) | `vmrestore -src=s3://bucket/vm/daily -storageDataPath=/victoria-metrics-data` |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| vmagent копит очередь | `vmagent_remotewrite_pending_data_bytes`, сеть до получателя |
| Ряды не пишутся, в логе `limit exceeded` | сработал `-storage.maxHourlySeries`: искать метрику в `/api/v1/status/tsdb` |
| Запрос падает `too many timeseries` | `-search.maxUniqueTimeseries`, сузить селектор |
| Упал один vmstorage | запись идёт на остальные; чтение неполное без `-replicationFactor` |
| Дубли точек от HA-пары | `-dedup.minScrapeInterval` = scrape interval |

> Проверка: флаги сверены с `-help` (victoria-metrics v1.122.0,
> vmagent/vmalert v1.148.0, vmbackup v1.122.0); MetricsQL-запросы и
> HTTP-эндпоинты single-node (query, status/tsdb, export, snapshot,
> delete_series, vmui) — на запущенном контейнере; `vmalert -dryRun`,
> `vmagent -dryRun` — выполнены; не проверено: `-replicationFactor`,
> URL и порты cluster-версии, `vmrestore`.
