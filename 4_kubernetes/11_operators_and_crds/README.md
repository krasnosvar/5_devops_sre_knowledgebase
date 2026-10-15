# 11. CRD и Operators

## Зачем
Argo CD `Application`, Karpenter `NodePool`, cert-manager
`Certificate`, KEDA `ScaledObject` — всё это не встроенные ресурсы, а
расширения API через CRD, за которыми стоит свой контроллер. Пока это
"магия", непонятно, почему CR создался, а ничего не произошло, или
почему оператор после рестарта не наплодил дубликатов. Тема сводит
всё к одному паттерну: CRD — схема данных, Operator — reconcile loop.

## Пререквизиты
- [01_architecture](../01_architecture/) — контроллеры, List+Watch,
  Informer.
- Желательно уже встретить готовые операторы в
  [09_gitops](../09_gitops/) и [10_pod_autoscaling](../10_pod_autoscaling/)
  — здесь объясняется, как они устроены.

## Файлы
- [01_theory/operators_and_crds.md](./01_theory/operators_and_crds.md)
  — CRD и OpenAPI-схема, reconcile loop, идемпотентность, операторы
  из других тем базы.
- [02_examples/](./02_examples/) — `website-crd.yaml` (схема,
  default, status subresource, printer columns), `website-cr.yaml`.
- [03_exercises/README.md](./03_exercises/README.md) — 3 упражнения,
  🐳 Tier 1 (kind).
- [04_exercises_answers/](./04_exercises_answers/) —
  [operators-answers.md](./04_exercises_answers/operators-answers.md),
  `website-extra.yaml`, скрипт-"оператор" `reconcile.sh`.

## Как проходить
1. Теория.
2. Упражнения 01-02 (CRD без оператора), затем 03 — написать свой
   reconcile-цикл на bash.
3. Сверка с ответами; запустить `reconcile.sh` в цикле и поиграть с
   CR и Deployment руками.

## Когда двигаться дальше
- Можете объяснить, что делает API-сервер для CR сам (валидация,
  default, хранение), а что — только контроллер.
- Знаете, почему Reconcile должен быть идемпотентным.
- Понимаете `served` vs `storage` у версий CRD.

Дальше — [12_k8s_ecosystem](../12_k8s_ecosystem/).
