# 06. VPC и облачные сети

## Зачем

В облаке нет физических коммутаторов, но есть VPC, подсети, таблицы
маршрутов, NAT Gateway, Security Groups и NACL. Ошибки в них — частая
причина «инстанс не видит интернет» и неожиданных счетов (NAT Gateway).

## Пререквизиты

- [03_load_balancing](../03_load_balancing/) и
  [05_iptables_and_nftables](../05_iptables_and_nftables/) — маршрутизация,
  NAT, stateful vs stateless фильтрация.

> **Забегание вперёд.** Здесь используется Terraform, который подробно
> разбирается в [5_iac/01_terraform_core](../../5_iac/01_terraform_core/).
> Для этой темы достаточно: `terraform init` / `plan` / `apply` / `destroy`
> и умения прочитать блок `resource`. Если Terraform ещё не освоен — эту
> часть можно пропустить и вернуться к ней позже.

> **Забегание вперёд.** Здесь используется AWS, который подробно
> разбирается в [7_compute_platforms/02_aws](../../7_compute_platforms/02_aws/).
> Для этой темы достаточно: аккаунт AWS и настроенные учётные данные для
> CLI/Terraform. Если AWS ещё не освоен — лабу можно пропустить: теория
> читается без неё.

## Файлы

- [01_theory/vpc_and_cloud_networking.md](./01_theory/vpc_and_cloud_networking.md)
  — VPC, subnets, IGW/NAT/Route Tables, SG vs NACL, Peering vs Transit
  Gateway.
- [02_examples/](./02_examples/) — `main.tf`, `variables.tf`: VPC с public и
  private подсетями, IGW, NAT Gateway, SG и NACL.
- [03_exercises/README.md](./03_exercises/README.md) — 4 упражнения
  (☁️ Tier 3: реальный аккаунт AWS, NAT Gateway платный).
- [04_exercises_answers/](./04_exercises_answers/) — ответы
  (`vpc_answers.md`).

## Как проходить

1. Прочитать теорию (лаба для неё не обязательна).
2. Если есть аккаунт AWS — `terraform plan`, затем `apply` примера и
   упражнения; в конце обязательно `terraform destroy`.
3. Сверить с `04_exercises_answers/`.

## Когда двигаться дальше

- Можете объяснить, чем public subnet отличается от private (маршрут, а не
  флаг).
- Можете объяснить разницу Security Group и NACL (stateful/stateless,
  allow/deny).
- Можете оценить стоимость NAT Gateway за месяц.

Дальше: раздел [3_containers](../../3_containers/).
