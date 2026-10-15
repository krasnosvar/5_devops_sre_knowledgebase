# 00. Первые шаги в Kubernetes

## Зачем
Прежде чем разбирать планировщик, сеть и etcd, нужно уметь поднять
кластер, понять, куда смотрит `kubectl`, и руками пройти путь
Pod → Deployment → Service. Это ежедневный минимум любой работы с
Kubernetes: посмотреть поды, прочитать логи, зайти внутрь контейнера,
применить манифест.

## Пререквизиты
- [3_containers](../../3_containers/) — что такое образ и контейнер,
  `docker run`/`docker exec`.
- [0_lab_setup/03_local_k8s](../../0_lab_setup/03_local_k8s/) —
  установленный kind (или minikube) и kubectl.

## Файлы
- [01_theory/first_steps.md](./01_theory/first_steps.md) — что такое
  кластер, control plane и ноды, Pod/Deployment/Service, kubeconfig и
  контексты, базовые команды kubectl, `--dry-run`, `kubectl explain`.
- [02_examples/](./02_examples/) — `kind-config.yaml` (кластер из
  3 нод), `pod.yaml`, `deployment.yaml`, `service.yaml`.
- [03_exercises/README.md](./03_exercises/README.md) — 6 упражнений,
  🐳 Tier 1 (kind).
- [04_exercises_answers/](./04_exercises_answers/) — ответы:
  [first-steps-answers.md](./04_exercises_answers/first-steps-answers.md).

## Как проходить
1. Прочитать теорию целиком (около получаса).
2. Поднять kind-кластер и применить примеры в порядке из §7 теории.
3. Сделать упражнения, не подглядывая в ответы.
4. Сверить команды и вывод с ответами.

## Когда двигаться дальше
- Можете объяснить, чем Pod отличается от Deployment и зачем Service.
- Без подсказки проверяете текущий контекст и namespace перед командой.
- Умеете найти причину "под не стартует" через `describe` и `logs`.
- Генерируете манифест через `--dry-run=client -o yaml` вместо набора
  руками.

Дальше — [01_architecture](../01_architecture/): что происходит внутри
control plane, когда вы делаете `kubectl apply`.
