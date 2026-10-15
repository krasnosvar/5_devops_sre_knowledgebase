# 08.2. Автоскейлинг нод: Cluster Autoscaler и Karpenter

## Зачем
HPA добавляет поды, но если им физически негде встать, они висят в
`Pending`. Кто-то должен заказать у облака новую ноду, а ночью —
вернуть лишние, иначе счёт за облако растёт впустую. Тема разбирает
два подхода: Cluster Autoscaler через группы нод и Karpenter с
выбором инстанса под конкретные поды.

## Пререквизиты
- [01_core](../01_core/) — статус `Pending` и drain.
- [05_scheduling](../../05_scheduling/) — `requests`, по которым
  планировщик считает свободное место.
- Автоскейлинг подов — [10_pod_autoscaling](../../10_pod_autoscaling/)
  (можно читать в любом порядке: темы независимы).

## Файлы
- [01_theory/node_autoscaling.md](./01_theory/node_autoscaling.md) —
  Cluster Autoscaler и ASG, Karpenter (`NodePool` +
  `EC2NodeClass`, API `karpenter.sh/v1`), Consolidation.

Без лабы: оба инструмента работают через API облачного провайдера, в
kind масштабировать нечего (☁️ Tier 3).

## Как проходить
1. Теория целиком.
2. Interview Q&A в конце — ответить самостоятельно.
3. Если есть доступ к облаку — сравнить YAML `NodePool` из теории с
   документацией актуальной версии Karpenter.

## Когда двигаться дальше
- Можете объяснить, почему Cluster Autoscaler не может создать ноду
  "с GPU", если такой группы нет, а Karpenter может.
- Знаете, что делает `consolidationPolicy: WhenEmptyOrUnderutilized`
  и чем рискует приложение без PDB.

Дальше — [09_gitops](../../09_gitops/).
