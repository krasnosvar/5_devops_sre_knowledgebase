# VPC и облачные сети — шпаргалка

Подробности и объяснения — в
[vpc_and_cloud_networking.md](./01_theory/vpc_and_cloud_networking.md). ⚠️ —
опасная команда или частая ловушка. Примеры — AWS; в GCP/Azure те же
понятия под другими именами.

## Компоненты

| Компонент | Что делает | Привязка |
| :--- | :--- | :--- |
| VPC | изолированная сеть, CIDR (например, `10.0.0.0/16` = 65 536 адресов) | регион |
| Subnet | кусок CIDR VPC (`10.0.1.0/24`) | одна AZ |
| Internet Gateway (IGW) | двусторонний доступ в интернет | VPC (один) |
| NAT Gateway | только исходящий доступ для private (SNAT), свой Elastic IP | живёт в public subnet, AZ |
| Route Table | longest prefix match, как `ip route` | subnet |
| Security Group | stateful, только Allow | ENI / инстанс |
| Network ACL | stateless, Allow + Deny, правила по номерам | subnet |
| VPC Peering | VPC ↔ VPC напрямую, без транзита | пара VPC |
| Transit Gateway | хаб «звезда» для многих VPC/VPN | регион |

## Public vs private subnet

```text
Public  RT: 10.0.0.0/16 -> local | 0.0.0.0/0 -> igw-...
Private RT: 10.0.0.0/16 -> local | 0.0.0.0/0 -> nat-...
```

| Признак | Public | Private |
| :--- | :--- | :--- |
| `0.0.0.0/0` в route table | → IGW | → NAT GW или нет |
| Доступен снаружи | да, если есть публичный IP | нет |
| Что размещать | ALB/NLB, NAT GW, bastion | приложения, БД, кэши |

- Маршрут `local` на CIDR VPC есть всегда и не удаляется — связность
  внутри VPC работает без IGW/NAT.
- Минимум 2 AZ на каждый тип подсети; ⚠️ NAT GW один на AZ — иначе отказ
  AZ с NAT режет исходящий трафик всех private-подсетей.
- В каждой подсети AWS резервирует 5 адресов (`/24` → 251 доступно).

## Security Group vs NACL

| | Security Group | Network ACL |
| :--- | :--- | :--- |
| Уровень | ENI / инстанс | вся подсеть |
| Состояние | stateful (ответ разрешён автоматически) | stateless (ответ — отдельным правилом) |
| Правила | только Allow | Allow и Deny, по возрастанию номера |
| Ссылки | можно на другой SG вместо CIDR | только CIDR |
| Когда | 95% случаев | явно заблокировать диапазон на всю подсеть |

⚠️ NACL stateless: для ответов нужен outbound/inbound на эфемерные порты
`1024-65535`, иначе «SYN уходит, ответ не возвращается».

## Peering vs Transit Gateway

| | VPC Peering | Transit Gateway |
| :--- | :--- | :--- |
| Топология | full mesh: `N*(N-1)/2` связей | звезда: N подключений |
| Транзитивность | нет (A↔B, B↔C ≠ A↔C) | есть, через route tables TGW |
| CIDR | ⚠️ не должны пересекаться | ⚠️ не должны пересекаться |
| Когда | 2–5 VPC | 10+ VPC, VPN/Direct Connect в одну точку |

## AWS CLI (только чтение)

| Задача | Команда |
| :--- | :--- |
| VPC и CIDR | `aws ec2 describe-vpcs --query 'Vpcs[].[VpcId,CidrBlock]' --output table` |
| Подсети VPC | `aws ec2 describe-subnets --filters Name=vpc-id,Values=vpc-xxx --query 'Subnets[].[SubnetId,AvailabilityZone,CidrBlock,MapPublicIpOnLaunch]' --output table` |
| Route table подсети | `aws ec2 describe-route-tables --filters Name=association.subnet-id,Values=subnet-xxx` |
| NAT / IGW | `aws ec2 describe-nat-gateways` / `aws ec2 describe-internet-gateways` |
| Правила SG | `aws ec2 describe-security-group-rules --filters Name=group-id,Values=sg-xxx` |
| NACL подсети | `aws ec2 describe-network-acls --filters Name=association.subnet-id,Values=subnet-xxx` |
| ENI по IP | `aws ec2 describe-network-interfaces --filters Name=addresses.private-ip-address,Values=10.0.1.15` |
| Peering / TGW | `aws ec2 describe-vpc-peering-connections` / `aws ec2 describe-transit-gateway-attachments` |
| Flow Logs (кто режет трафик) | `aws ec2 describe-flow-logs`; включить: `aws ec2 create-flow-logs --resource-type VPC --resource-ids vpc-xxx --traffic-type REJECT --log-destination-type s3 --log-destination arn:aws:s3:::bucket` |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| Private-инстанс не качает пакеты | RT: `0.0.0.0/0 -> nat-...`; NAT GW в public subnet; RT public → IGW |
| Публичный IP есть, снаружи недоступен | RT подсети ведёт в NAT, а не IGW; SG inbound; NACL |
| Подключение висит (таймаут) | SG/NACL дропают: Flow Logs `REJECT` |
| Работает в одну сторону | NACL без правила на эфемерные порты |
| Peering есть, трафика нет | маршруты в RT **обеих** VPC, SG, пересечение CIDR |
| Большой счёт за NAT | межзональный трафик через NAT, нет VPC endpoint для S3/DynamoDB |

> Проверка: подкоманды и параметры AWS CLI 2.37 сверены через
> `--generate-cli-skeleton` (без API-вызовов); не проверено: реальный вывод
> команд (нужен аккаунт AWS).
