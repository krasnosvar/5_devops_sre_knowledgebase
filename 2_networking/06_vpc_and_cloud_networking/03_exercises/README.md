# Упражнения — VPC и облачная сеть

Стенд: ☁️ Tier 3 — AWS free tier (NAT Gateway и Elastic IP не бесплатны, но
free tier + 1-2 часа лабы обойдётся в центы, не забудь `terraform destroy`)

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
