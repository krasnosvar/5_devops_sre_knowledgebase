# Ответы — CRD и Operators

Команды выполняются из каталога `11_operators_and_crds/03_exercises/` на
kind-кластере. Файлы ответов:
- [`website-extra.yaml`](./website-extra.yaml) — второй валидный
  `Website` и заведомо невалидный (для проверки схемы CRD);
- [`reconcile.sh`](./reconcile.sh) — скрипт-"оператор" из упражнения 03.

## Упражнение 01 — CRD без Operator: схема есть, поведения нет

```bash
kubectl apply -f ../02_examples/website-crd.yaml
kubectl apply -f ../02_examples/website-cr.yaml

kubectl get websites
kubectl get ws
kubectl get deployments

# Бонус: схема и defaulting работают и без оператора
kubectl apply -f ../04_exercises_answers/website-extra.yaml
kubectl get website shop -o jsonpath='{.spec.replicas}{"\n"}'
```

Ожидаемый вывод (примерно так):

```text
customresourcedefinition.apiextensions.k8s.io/websites.example.com created
website.example.com/my-blog created
NAME      DOMAIN             PHASE
my-blog   blog.example.com
NAME      DOMAIN             PHASE
my-blog   blog.example.com
No resources found in default namespace.
website.example.com/shop created
The Website "broken" is invalid: spec.domain: Required value
1
```

Почему так: CRD научил API-сервер хранить, валидировать (`required:
[domain]`) и дополнять значениями по умолчанию (`default: 1`) объекты
`Website` — это делает сам API-сервер. Но ни одного Deployment не
появилось: превращать `Website` в реальные ресурсы некому, контроллера
нет. `PHASE` пустой — `status` тоже никто не пишет.

## Упражнение 02 — additionalPrinterColumns

```bash
kubectl get websites -o wide
kubectl get configmaps
```

Ожидаемый вывод (примерно так):

```text
NAME      DOMAIN             PHASE
my-blog   blog.example.com
NAME               DATA   AGE
kube-root-ca.crt   1      17h
```

Почему так: колонки задаёт сам CRD в `additionalPrinterColumns` —
`kubectl` получает от API-сервера готовую таблицу (`Table`), а
`jsonPath` указывает, откуда брать значения (`.spec.domain`,
`.status.phase`). Для встроенных ресурсов (ConfigMap) колонки зашиты в
API-сервер. Подвох: как только `additionalPrinterColumns` заданы, колонка
`AGE` по умолчанию пропадает — её добавляют явно
(`jsonPath: .metadata.creationTimestamp`, `type: date`).

## Упражнение 03 — Симуляция Reconcile (без написания настоящего оператора)

Скрипт [`reconcile.sh`](./reconcile.sh): для каждого `Website` создаёт
Deployment `website-<name>` (nginx), выравнивает `replicas` по
`spec.replicas`, пишет `status.phase` через subresource `status` и
удаляет Deployment'ы, чей `Website` удалён (их находит по label
`example.com/website`).

```bash
kubectl apply -f ../02_examples/website-cr.yaml
../04_exercises_answers/reconcile.sh --once
kubectl get ws
../04_exercises_answers/reconcile.sh --once          # второй проход — ничего

# изменить желаемое состояние
kubectl patch website my-blog --type=merge -p '{"spec":{"replicas":3}}'
../04_exercises_answers/reconcile.sh --once

# создать дрейф руками
kubectl scale deploy website-my-blog --replicas=1
../04_exercises_answers/reconcile.sh --once

# удалить CR — Deployment должен уйти следом
kubectl delete website my-blog
../04_exercises_answers/reconcile.sh --once

# в фоне как настоящий контроллер (Ctrl+C — остановить)
../04_exercises_answers/reconcile.sh
```

Ожидаемый вывод (примерно так):

```text
create  website-my-blog (replicas=2)
NAME      DOMAIN             PHASE
my-blog   blog.example.com   Reconciled
website.example.com/my-blog patched
scale   website-my-blog 2 -> 3
scale   website-my-blog 1 -> 3
website.example.com "my-blog" deleted from default namespace
delete  website-my-blog (Website my-blog удалён)
```

Почему так: каждый проход заново сравнивает желаемое с фактическим и
ничего не помнит о прошлых проходах — поэтому второй запуск подряд
ничего не делает (идемпотентность), а ручной `scale` исправляется так
же, как изменение CR. Отличия от настоящего оператора: вместо Informer
(watch + локальный кэш) — опрос раз в `INTERVAL` секунд, вместо
ownerReferences и сборщика мусора — ручной поиск сирот по label, нет
очереди с повторами при ошибках.
