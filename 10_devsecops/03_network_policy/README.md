# 03. NetworkPolicy

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — команды и шаблоны одним экраном.

## Зачем
По умолчанию в Kubernetes любой Pod может обратиться к любому другому —
взломанный frontend сразу видит базу данных. NetworkPolicy позволяет
построить default-deny и открыть только нужные потоки трафика.

## Пререквизиты
- [4_kubernetes/03_networking](../../4_kubernetes/03_networking/) —
  Service, DNS, CNI.
- [2_networking](../../2_networking/) — L3/L4, порты, TCP.

## Файлы
- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: селекторы, default-deny.
- [01_theory/network_policy.md](./01_theory/network_policy.md) —
  default deny, ingress/egress, паттерны, отладка, ограничения.
- [02_examples/netpol-demo.yaml](./02_examples/netpol-demo.yaml) —
  демо-приложение с набором политик.
- Упражнений нет: практика NetworkPolicy есть в
  [4_kubernetes/06_security/01_core](../../4_kubernetes/06_security/01_core/03_exercises/README.md).

## Как проходить
1. Прочитать теорию.
2. Применить `netpol-demo.yaml` в kind кластере с CNI, который
   поддерживает NetworkPolicy (Calico или Cilium; стандартный kindnet
   политики не применяет), и проверить связность.

## Когда двигаться дальше
- Можете объяснить, почему после default-deny egress ломается DNS.
- Можете написать политику «backend принимает только от frontend».

Далее: [04_image_security](../04_image_security/).
