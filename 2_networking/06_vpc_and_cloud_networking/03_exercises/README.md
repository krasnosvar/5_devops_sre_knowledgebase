# Упражнения — VPC и облачная сеть

Стенд: ☁️ Tier 3 — реальный аккаунт AWS. NAT Gateway и публичные IPv4
(Elastic IP) тарифицируются почасово в любом случае; 1-2 часа лабы обычно
стоят порядка доллара, но не забудь `terraform destroy`. Условия бесплатного
уровня AWS меняются: с июля 2025 новые аккаунты получают план на основе
кредитов вместо прежнего 12-месячного free tier — проверь актуальные условия
своего аккаунта перед стартом.

> **Забегание вперёд.** Здесь используется Terraform, который подробно
> разбирается в [5_iac/01_terraform_core](../../../5_iac/01_terraform_core/).
> Для этой темы достаточно: `terraform init` / `plan` / `apply` / `destroy`
> в каталоге с `.tf`-файлами и умения прочитать блок `resource`. Если
> Terraform ещё не освоен — эту часть можно пропустить и вернуться к ней
> позже.

> **Забегание вперёд.** Здесь используется AWS (VPC, EC2, консоль, учётные
> данные для CLI), который подробно разбирается в
> [7_compute_platforms/02_aws](../../../7_compute_platforms/02_aws/). Для этой
> темы достаточно: аккаунт AWS, настроенные учётные данные (`aws configure`
> или переменные `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`) и доступ к VPC
> Dashboard в консоли. Если AWS ещё не освоен — лабу можно пропустить: теория
> темы читается без неё.

```bash
cd ../02_examples
terraform init
terraform plan -var="region=eu-central-1"
```

## 01 — Поднять базовую топологию

```bash
terraform apply -var="region=eu-central-1"
# TODO: в консоли AWS (VPC Dashboard) найди созданную VPC, обе подсети,
# Internet Gateway и NAT Gateway — свяжи каждый ресурс с соответствующим
# блоком в main.tf
```

## 02 — Проверить связность: public достижим, private — нет

**Задача:** Поднять EC2-инстанс в public subnet, попробовать поднять такой же в private — убедиться, что он недостижим напрямую по SSH.

```bash
# TODO: добавь в main.tf aws_instance в aws_subnet.public.id с associate_public_ip_address = true
# и второй — в aws_subnet.private.id, без публичного IP
terraform apply

# Проверить SSH-доступ к public-инстансу — должен работать (если открыт SG на 22)
# Проверить SSH-доступ к private-инстансу напрямую по его private IP из интернета — не сработает
```

## 03 — Security Group не умеет Deny — проверить NACL

```bash
# TODO: попробуй добавить "deny"-правило в aws_security_group.app (ingress/egress)
# и убедись что провайдер AWS вообще не поддерживает такое поле — Security Group
# в API AWS способен только на Allow. Explicit Deny возможен только через
# aws_network_acl (уже есть в main.tf — найди правило rule_no = 90)
```

## 04 — Посчитать стоимость NAT Gateway

```
# TODO (письменно): NAT Gateway в AWS тарифицируется и почасово, и за трафик.
# Посмотри текущую цену в вашем регионе (aws.amazon.com/vpc/pricing) и посчитай,
# сколько будет стоить NAT Gateway, работающий круглосуточно месяц, если через
# него проходит база в 100GB/месяц. Это частый "сюрприз" в облачном счёте.
```

## Не забудь снести стенд

```bash
terraform destroy -var="region=eu-central-1"
```
