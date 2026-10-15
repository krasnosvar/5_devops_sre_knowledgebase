# 08. Dashboards as Code

## Зачем
Дашборды, накликанные руками, теряются при пересоздании Grafana,
расходятся между окружениями и не проходят ревью. Хранение дашбордов в
Git (JSON, Jsonnet, CRD, Terraform) делает их воспроизводимыми и
версионируемыми, как любой другой код инфраструктуры.

## Пререквизиты
- [04_grafana](../04_grafana/) — provisioning и экспорт дашборда через
  API (упражнение 04).
- [5_iac](../../5_iac/) — для подхода через Terraform provider.
- Git — в этой базе не преподаётся, см.
  [01_git_essentials](../../../4_python_my_knowledgebase/0_tooling_and_workflow/01_git_essentials/).

> **Забегание вперёд.** Подходы с ConfigMap и `GrafanaDashboard` CRD
> опираются на [4_kubernetes](../../4_kubernetes/) и Helm
> ([07_manifests_management](../../4_kubernetes/07_manifests_management/)).
> Для этой темы достаточно: ConfigMap, CRD как понятие. Если Kubernetes
> ещё не освоен — эти подходы можно пропустить и вернуться к ним позже.

## Файлы
- [01_theory/dashboards_as_code.md](./01_theory/dashboards_as_code.md)
  — почему не кликать, provisioning из JSON/ConfigMap, CRD
  kube-prometheus-stack / grafana-operator, Jsonnet/Grafonnet,
  Terraform provider, вопросы с собеседований.
- [02_examples/export-import.sh](./02_examples/export-import.sh) —
  экспорт/импорт всех дашбордов и deploy-аннотации через Grafana API:
  `./export-import.sh export ./dashboards`.

Отдельных упражнений нет: скрипт запускается против Grafana из стенда
[02_metrics_prometheus](../02_metrics_prometheus/02_examples/).

## Как проходить
1. Прочитать теорию.
2. Поднять стенд Prometheus + Grafana, создать пару дашбордов
   (упражнения [04_grafana](../04_grafana/03_exercises/README.md)).
3. Выгрузить их скриптом в каталог, удалить в UI, загрузить обратно.

## Когда двигаться дальше
- Можете назвать 3-4 подхода к dashboards as code и когда какой
  выбирать.
- Понимаете, зачем при экспорте удалять `id` и `version`.
- Можете вернуть удалённый дашборд из Git без ручного кликанья.

Дальше — [09_observability_at_scale](../09_observability_at_scale/).
