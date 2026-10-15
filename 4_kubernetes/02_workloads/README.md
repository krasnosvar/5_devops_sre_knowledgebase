# 02. Workloads: Pod, Deployment, StatefulSet, DaemonSet, Job

## Зачем
Каждое приложение в Kubernetes запускается через один из контроллеров
нагрузки, и выбор неправильного (Deployment для базы данных, голый Pod
для сервиса) приводит к потере данных или простою при обновлении. Тема
учит выбирать контроллер, настраивать rolling update и probes и
понимать, кого кластер убьёт первым при нехватке памяти.

## Пререквизиты
- [01_architecture](../01_architecture/) — какие контроллеры за что
  отвечают, роль kubelet.
- [00_first_steps](../00_first_steps/) — базовые команды kubectl.

## Файлы
- [01_theory/workloads.md](./01_theory/workloads.md) — анатомия пода и
  pause-контейнер, rolling update (maxSurge/maxUnavailable),
  StatefulSet, DaemonSet, Job и CronJob.
- [02_examples/](./02_examples/) — `deployment.yaml` (Deployment +
  Service + HPA), `statefulset.yaml` (PostgreSQL с headless Service и
  volumeClaimTemplates).
- [03_exercises/README.md](./03_exercises/README.md) — 5 упражнений,
  🐳 Tier 1 (kind, для DaemonSet — многонодовый).
- [04_exercises_answers/](./04_exercises_answers/) —
  [workloads-answers.md](./04_exercises_answers/workloads-answers.md)
  (команды и ожидаемый вывод) и
  [workloads-answer.yaml](./04_exercises_answers/workloads-answer.yaml)
  (манифесты).

## Как проходить
1. Теория → примеры (`kubectl apply -f 02_examples/...`).
2. Упражнения 01-05, манифесты писать самостоятельно.
3. Сверка с `workloads-answers.md`; отличия в манифестах разобрать по
   комментариям в `workloads-answer.yaml`.

## Когда двигаться дальше
- Можете без подсказки выбрать Deployment / StatefulSet / DaemonSet /
  Job для конкретной задачи и объяснить почему.
- Можете рассчитать, сколько подов будет во время rolling update при
  заданных `replicas`, `maxSurge`, `maxUnavailable`.
- Можете объяснить разницу readiness и liveness и что происходит с
  трафиком при провале readiness.

Дальше — [03_networking](../03_networking/).
