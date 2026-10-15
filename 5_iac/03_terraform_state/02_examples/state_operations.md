# Операции с Terraform state — справочник команд

> **Внимание.** Это не скрипт и не запускается целиком. Команды ниже
> меняют state живой инфраструктуры: `state rm`, `state mv`, `import`
> и `force-unlock` выполняются по одной, осознанно, на выбранном
> окружении. Адреса (`aws_instance.web`, `module.vpc` и т. п.) —
> примеры, подставляйте свои.

Перед любой модификацией state:

```bash
terraform workspace show                 # то ли окружение выбрано?
terraform state pull > backup-$(date +%F-%H%M).tfstate   # локальная копия
```

Remote backend с версионированием бакета даёт ещё одну точку отката,
но локальная копия перед ручной операцией дешевле, чем восстановление.

## Просмотр (безопасно)

```bash
terraform state list                     # все адреса в state
terraform state list 'module.vpc'        # фильтр по префиксу адреса
terraform state show aws_instance.web    # атрибуты одного ресурса
terraform state pull > current.tfstate   # скачать state (содержит секреты!)
```

`current.tfstate` содержит секреты в открытом виде: не коммитить, удалить
после использования.

## Перемещение (переименование без пересоздания)

Предпочтительный способ (Terraform 1.1+) — блок `moved` в коде: он
проходит через `plan` и ревью.

```hcl
moved {
  from = aws_instance.old
  to   = aws_instance.new
}
```

CLI-вариант (меняет state сразу, без плана):

```bash
terraform state mv aws_instance.old aws_instance.new
terraform state mv 'module.old.aws_s3_bucket.data' 'module.new.aws_s3_bucket.data'
terraform plan     # должно быть: No changes
```

## Удаление из state (ресурс остаётся в облаке)

> **Опасно.** После `state rm` Terraform «забывает» ресурс: он
> продолжает работать и стоить денег, но больше не управляется. Если
> блок ресурса остался в коде, следующий `apply` попытается создать
> его заново (дубль или конфликт имён).

Декларативная альтернатива (Terraform 1.7+) — блок `removed` с
`lifecycle { destroy = false }`:

```hcl
removed {
  from = aws_instance.temp
  lifecycle {
    destroy = false
  }
}
```

CLI-вариант:

```bash
terraform state rm aws_instance.temp
terraform state rm 'module.eks.aws_eks_cluster.this[0]'

# Сначала посмотреть, ЧТО будет удалено из state, и только потом удалять:
terraform state list | grep '^module.legacy'
terraform state rm 'module.legacy'       # весь модуль одним адресом
```

## Import существующих ресурсов

Предпочтительно (Terraform 1.5+) — блок `import`, виден в `plan`:

```hcl
import {
  to = aws_s3_bucket.logs
  id = "my-logs-bucket"
}
```

```bash
terraform plan -generate-config-out=generated.tf   # черновик кода
terraform plan                                     # 1 to import, ...
```

CLI-вариант (блок `resource` уже должен быть в коде, адреса в state
быть не должно):

```bash
terraform import aws_s3_bucket.logs my-logs-bucket
terraform import aws_instance.web i-0abc123def456
terraform import 'aws_subnet.private[0]' subnet-0abc123
terraform plan     # цель: No changes или ожидаемые изменения
```

## Восстановление из версии в S3

```bash
aws s3api list-object-versions \
    --bucket my-tfstate-prod \
    --prefix services/myapp/terraform.tfstate \
    --query 'Versions[*].[VersionId,LastModified]' \
    --output table

aws s3api get-object \
    --bucket my-tfstate-prod \
    --key services/myapp/terraform.tfstate \
    --version-id VERSIONID \
    backup.tfstate
```

Залить обратно — `terraform state push backup.tfstate` (Terraform
откажет, если serial старше текущего; `-force` использовать только
понимая, что перезаписываете чужие изменения).

## Снятие застрявшего lock

> **Опасно.** Сначала убедиться, что никакой `apply` (CI, коллега) в
> этот момент реально не идёт: снятие живого lock приводит к
> одновременной записи state.

```bash
terraform force-unlock LOCK_ID   # LOCK_ID — из сообщения об ошибке
```

## Drift detection

```bash
terraform plan -refresh-only     # показать drift, ничего не меняя
terraform apply -refresh-only    # записать реальность в state (спросит yes)
terraform plan -detailed-exitcode  # для CI: 0 — нет изменений, 2 — есть
```
