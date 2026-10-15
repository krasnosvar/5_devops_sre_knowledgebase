# alerts/

Сюда кладутся rule-файлы Prometheus (`*.yml`): `prometheus.yml` читает их
через `rule_files: ["alerts/*.yml"]`, каталог смонтирован в контейнер как
`/etc/prometheus/alerts`. После добавления файла:
`curl -X POST http://localhost:9090/-/reload`.
