# Ответы — Kustomize

Команды выполняются из каталога `03_kustomize/02_examples/` (как в
упражнениях). Готовые оверлеи с решениями:
- [`overlays/dev/`](./overlays/dev/) — упражнение 03 (`$patch: delete`);
- [`overlays/prod/`](./overlays/prod/) — упражнение 04 (JSON Patch).

Оверлеи-ответы ссылаются на тот же base:
`resources: [../../../02_examples/base]`.

## Упражнение 01 — Собрать base + overlay и посмотреть на разницу окружений

```bash
kubectl kustomize base/ | head -30

kubectl kustomize overlays/dev/ > /tmp/dev.yaml
kubectl kustomize overlays/prod/ > /tmp/prod.yaml
diff /tmp/dev.yaml /tmp/prod.yaml
```

Ожидаемый вывод `diff` (примерно так):

```text
3,4c3,4
<   LOG_LEVEL: debug
<   MAX_CONNECTIONS: "100"
---
>   LOG_LEVEL: warn
>   MAX_CONNECTIONS: "1000"
7,8c7,8
<   name: myapp-config-72bg55kb99
<   namespace: myapp-dev
---
>   name: myapp-config-dc8f26c487
>   namespace: myapp-prod
...
<   replicas: 1
---
>   replicas: 3
...
<         image: myapp:dev
---
>         image: myapp:v1.4.2
```

Почему так: оверлеи отличаются namespace, патчем replicas/image и
literals в `configMapGenerator` (`behavior: merge` дописывает/заменяет
ключи base). Разные данные ConfigMap → разный хэш-суффикс в имени, и
ссылка `configMapRef` в Deployment переписана автоматически.

## Упражнение 02 — ConfigMapGenerator и автоматический Rolling Update

```bash
kubectl apply -k overlays/dev/ --dry-run=client -o yaml | grep -A2 "kind: ConfigMap"
kubectl kustomize overlays/dev/ | grep -A2 "kind: ConfigMap"

# поменять LOG_LEVEL=debug на LOG_LEVEL=trace
sed -i 's/LOG_LEVEL=debug/LOG_LEVEL=trace/' overlays/dev/kustomization.yaml
kubectl kustomize overlays/dev/ | grep -A2 "kind: ConfigMap"
kubectl kustomize overlays/dev/ | grep -A1 "configMapRef"

# вернуть файл как было
sed -i 's/LOG_LEVEL=trace/LOG_LEVEL=debug/' overlays/dev/kustomization.yaml
```

Ожидаемый вывод (примерно так):

```text
kind: ConfigMap
metadata:
  name: myapp-config-72bg55kb99
kind: ConfigMap
metadata:
  name: myapp-config-mbmk4ctdm8
        - configMapRef:
            name: myapp-config-mbmk4ctdm8
```

Почему так: новое содержимое → новое имя ConfigMap → изменился
`spec.template` Deployment (ссылка на ConfigMap) → контроллер Deployment
запускает Rolling Update при `kubectl apply -k`. Старый ConfigMap
остаётся и нужен для отката, пока его не удалят (например, `prune` в
GitOps).

## Упражнение 03 — Удалить ресурс из base через `$patch: delete`

Решение — [`overlays/dev/patch-delete-ingress.yaml`](./overlays/dev/patch-delete-ingress.yaml)
и строка `- path: patch-delete-ingress.yaml` в
[`overlays/dev/kustomization.yaml`](./overlays/dev/kustomization.yaml).

```bash
kubectl kustomize ../04_exercises_answers/overlays/dev/ | grep -c "kind: Ingress"
kubectl kustomize ../04_exercises_answers/overlays/prod/ | grep -c "kind: Ingress"
```

Ожидаемый вывод:

```text
0
1
```

Почему так: `$patch: delete` стоит на верхнем уровне документа рядом с
`apiVersion`/`kind`, Kustomize находит в base объект с тем же
`kind`+`metadata.name` и выкидывает его из результата. Base не менялся,
поэтому в prod Ingress остался.

## Упражнение 04 — JSON Patch: точечное изменение аргумента запуска

Решение — inline-патч с `op: add` в
[`overlays/prod/kustomization.yaml`](./overlays/prod/kustomization.yaml).

```bash
kubectl kustomize ../04_exercises_answers/overlays/prod/ | grep -A3 "args:"
```

Ожидаемый вывод (примерно так):

```text
      - args:
        - --verbose=false
        envFrom:
        - configMapRef:
```

Почему так: JSON Patch адресует поле по пути
`/spec/template/spec/containers/0/args`; `op: add` создаёт массив,
которого в base не было. Если `args` уже существует, `add` с этим путём
заменит его целиком — чтобы дописать элемент в конец, используют путь
`.../args/-`.
