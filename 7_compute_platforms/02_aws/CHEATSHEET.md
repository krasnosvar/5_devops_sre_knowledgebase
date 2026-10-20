# AWS — шпаргалка

Подробности и объяснения — в [01_theory/](./01_theory/) (начинать с
[00_aws_core.md](./01_theory/00_aws_core.md)). ⚠️ — опасная команда или
частая ловушка.

## AWS CLI: профили, вывод, фильтры

Подробно: [00_aws_core.md](./01_theory/00_aws_core.md).

| Задача | Команда |
| :--- | :--- |
| Кто я (аккаунт, ARN роли) — первая команда при отладке | `aws sts get-caller-identity` |
| Настроить профиль с ключами / через SSO | `aws configure --profile dev` / `aws configure sso` |
| Войти по SSO | `aws sso login --profile dev` |
| Выбрать профиль и регион | `--profile dev --region eu-central-1` или `export AWS_PROFILE=dev AWS_REGION=eu-central-1` |
| Формат вывода | `--output json\|table\|text\|yaml` |
| Выбрать поля (JMESPath, на клиенте) | `--query 'Reservations[].Instances[].[InstanceId,State.Name]'` |
| Отфильтровать на сервере | `--filters Name=tag:Env,Values=prod Name=instance-state-name,Values=running` |
| Без пейджера | `--no-cli-pager` или `export AWS_PAGER=""` |
| Проверить права без изменения (EC2) | `--dry-run` (ответ `DryRunOperation` = права есть) |
| Скелет JSON-параметров | `aws ec2 run-instances --generate-cli-skeleton` |
| Справка по операции | `aws ec2 describe-instances help` |
| Ждать состояния | `aws ec2 wait instance-running --instance-ids i-...` |

- ⚠️ `--query` фильтрует уже скачанное; на больших списках сначала
  `--filters`, иначе медленно и упирается в пагинацию.
- ⚠️ Порядок поиска кредов: флаги → env → `~/.aws/credentials`/`config`
  → роль инстанса/контейнера. «Не те права» — почти всегда не тот профиль.

## IAM и STS

Подробно: [01_aws_iam_and_security.md](./01_theory/01_aws_iam_and_security.md).

| Задача | Команда |
| :--- | :--- |
| Создать роль с trust policy | `aws iam create-role --role-name MyEC2Role --assume-role-policy-document file://trust.json` |
| Прикрепить managed-политику | `aws iam attach-role-policy --role-name MyEC2Role --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess` |
| Политики роли | `aws iam list-attached-role-policies --role-name MyEC2Role` |
| Принять роль (временные ключи) | `aws sts assume-role --role-arn arn:aws:iam::123456789012:role/X --role-session-name dbg` |
| Проверить, разрешит ли политика | `aws iam simulate-principal-policy --policy-source-arn <role-arn> --action-names s3:GetObject` |
| Раскодировать «encoded authorization failure» | `aws sts decode-authorization-message --encoded-message <msg>` |
| ⚠️ Отключить утёкший ключ | `aws iam update-access-key --user-name u --access-key-id AKIA... --status Inactive` |

| Правило вычисления прав | Итог |
| :--- | :--- |
| Нет ни одного Allow | Deny (default deny) |
| Есть явный Deny где угодно | Deny — перекрывает всё |
| Allow и нет Deny | Allow |
| Permission Boundary / SCP | права = пересечение с границей |
| Cross-account | нужен Allow **с обеих сторон** (роль + resource policy) |

| Что выбрать | Когда |
| :--- | :--- |
| IAM Role (+ instance profile) | EC2, Lambda, ECS — никогда не ключи на инстансе |
| OIDC (`AssumeRoleWithWebIdentity`) | CI (GitHub/GitLab) вместо `AWS_ACCESS_KEY_ID` в секретах |
| IRSA / EKS Pod Identity | права для подов EKS |
| SSM Parameter Store `SecureString` | конфиги и пароли, бесплатно (standard) |
| Secrets Manager | нужна авто-ротация (RDS), $0.40 за секрет |
| KMS customer managed key | своя key policy, cross-account, контроль ротации |

## VPC

Подробно: [02_aws_networking_vpc.md](./01_theory/02_aws_networking_vpc.md).

| Задача | Команда |
| :--- | :--- |
| Список VPC | `aws ec2 describe-vpcs --query 'Vpcs[].[VpcId,CidrBlock]' --output table` |
| Подсети VPC | `aws ec2 describe-subnets --filters Name=vpc-id,Values=vpc-... --query 'Subnets[].[SubnetId,AvailabilityZone,CidrBlock]'` |
| Таблицы маршрутов | `aws ec2 describe-route-tables --filters Name=vpc-id,Values=vpc-...` |
| Создать SG | `aws ec2 create-security-group --group-name web-sg --description "web" --vpc-id vpc-...` |
| Открыть порт | `aws ec2 authorize-security-group-ingress --group-id sg-... --protocol tcp --port 443 --cidr 0.0.0.0/0` |
| Правила SG | `aws ec2 describe-security-group-rules --filters Name=group-id,Values=sg-...` |
| VPC Endpoints | `aws ec2 describe-vpc-endpoints` |
| Включить Flow Logs в S3 | `aws ec2 create-flow-logs --resource-type VPC --resource-ids vpc-... --traffic-type REJECT --log-destination-type s3 --log-destination arn:aws:s3:::bucket` |

| | Security Group | NACL |
| :--- | :--- | :--- |
| Уровень | ENI (инстанс) | подсеть |
| Состояние | stateful | stateless — эфемерные порты `1024-65535` явно |
| Deny-правила | нет | есть |
| Порядок | все правила вместе | по номеру, первое совпадение |
| По умолчанию | ingress закрыт, egress открыт | default NACL: всё разрешено |

| Задача | Решение |
| :--- | :--- |
| Приватной подсети нужен интернет | NAT Gateway в публичной подсети (по одному на AZ для HA) |
| S3/DynamoDB без NAT | Gateway Endpoint — бесплатно |
| SQS/KMS/STS/ECR без NAT | Interface Endpoint (PrivateLink) + Private DNS |
| 2–3 VPC | VPC Peering (не транзитивен, CIDR не пересекаются) |
| Много VPC / on-prem | Transit Gateway |
| IPv6 только наружу | Egress-Only Internet Gateway |

- ⚠️ В каждой подсети AWS резервирует 5 адресов: `/24` = 251 адрес.
- ⚠️ NAT Gateway — плата за каждый GB: тяжёлый трафик в S3/ECR пускайте
  через endpoints.

## EC2, EBS, ASG, ELB

Подробно: [03_aws_compute_ec2.md](./01_theory/03_aws_compute_ec2.md).

| Задача | Команда |
| :--- | :--- |
| Запущенные инстансы | `aws ec2 describe-instances --filters Name=instance-state-name,Values=running --query 'Reservations[].Instances[].[InstanceId,InstanceType,PrivateIpAddress,Tags[?Key=='Name']\|[0].Value]' --output table` |
| Актуальная AMI Ubuntu 24.04 | `aws ssm get-parameters --names /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id` |
| Запустить инстанс | `aws ec2 run-instances --image-id ami-... --instance-type t3.micro --subnet-id subnet-... --security-group-ids sg-... --iam-instance-profile Name=MyEC2Role --user-data file://userdata.sh --metadata-options HttpTokens=required` |
| Spot-инстанс | `--instance-market-options '{"MarketType":"spot"}'` |
| Стоп / старт | `aws ec2 stop-instances --instance-ids i-...` / `start-instances` |
| ⚠️ Удалить инстанс | `aws ec2 terminate-instances --instance-ids i-...` |
| Консоль без SSH-порта | `aws ssm start-session --target i-...` |
| Вывод консоли (не грузится) | `aws ec2 get-console-output --instance-id i-... --latest --output text` |
| Status checks | `aws ec2 describe-instance-status --instance-ids i-...` |
| Требовать IMDSv2 | `aws ec2 modify-instance-metadata-options --instance-id i-... --http-tokens required` |
| gp2 → gp3 без простоя | `aws ec2 modify-volume --volume-id vol-... --volume-type gp3` |
| Снапшот тома | `aws ec2 create-snapshot --volume-id vol-... --description "pre-upgrade"` |
| Неиспользуемые EBS | `aws ec2 describe-volumes --filters Name=status,Values=available` |
| Состояние таргетов LB | `aws elbv2 describe-target-health --target-group-arn arn:...` |
| ASG: размер и инстансы | `aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names web-asg` |
| ASG: заменить инстансы | `aws autoscaling start-instance-refresh --auto-scaling-group-name web-asg` |

IMDSv2 изнутри инстанса:

```bash
TOKEN=$(curl -sX PUT http://169.254.169.254/latest/api/token \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/iam/security-credentials/
```

| Семейство | Назначение |
| :--- | :--- |
| `t3`/`t4g` | burstable (кредиты CPU) — dev, мелкий web; ⚠️ не для постоянной нагрузки |
| `m` | баланс CPU/RAM |
| `c` | compute — CI-раннеры, CPU-bound |
| `r` | memory — БД, кэши |
| `i` | локальные NVMe (instance store) |
| `p`, `g` (семейства) | GPU |
| суффикс `g` (`m7g`, `c6g`) | Graviton (ARM), дешевле x86 |

| Выбор | Когда |
| :--- | :--- |
| ALB (L7) | HTTP-маршрутизация по path/host, TLS-терминация; IP меняются → Alias/CNAME |
| NLB (L4) | TCP/UDP, статические IP, сохранение IP клиента |
| GWLB (L3) | вставка сторонних firewall-апплайнсов |
| EBS `gp3` | дефолт: 3000 IOPS из коробки независимо от размера |
| EBS `io2` | тяжёлые БД, до 256 000 IOPS |
| Instance store | кэш/scratch; ⚠️ данные теряются при stop/terminate |
| Placement `cluster` / `spread` | HPC, низкая задержка / изоляция отказов по стойкам |

- ⚠️ ASG по умолчанию проверяет только EC2 status checks — для замены
  «живого, но больного» инстанса `Health Check Type = ELB`.
- ⚠️ Долгий старт приложения → увеличить `HealthCheckGracePeriod`, иначе
  ASG убивает инстансы по кругу.

## S3

Подробно: [04_aws_storage_s3.md](./01_theory/04_aws_storage_s3.md).

| Задача | Команда |
| :--- | :--- |
| Создать бакет | `aws s3 mb s3://my-bucket --region eu-central-1` |
| Список / размер префикса | `aws s3 ls s3://my-bucket/prefix/ --recursive --human-readable --summarize` |
| Копировать | `aws s3 cp file.txt s3://my-bucket/` (большие файлы — multipart автоматически) |
| ⚠️ Синхронизировать с удалением | `aws s3 sync ./dir s3://my-bucket/prefix/ --delete` (сначала `--dryrun`) |
| Временная ссылка | `aws s3 presign s3://my-bucket/f.pdf --expires-in 900` |
| Включить версионирование | `aws s3api put-bucket-versioning --bucket b --versioning-configuration Status=Enabled` |
| Block Public Access | `aws s3api put-public-access-block --bucket b --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true` |
| Lifecycle | `aws s3api put-bucket-lifecycle-configuration --bucket b --lifecycle-configuration file://lc.json` |
| Версии объекта (найти delete marker) | `aws s3api list-object-versions --bucket b --prefix config.json` |
| Восстановить удалённое (снять delete marker) | `aws s3api delete-object --bucket b --key config.json --version-id <marker-id>` |
| Бакет-политика | `aws s3api get-bucket-policy --bucket b` |

| Класс | Когда | Ловушка |
| :--- | :--- | :--- |
| Standard | частый доступ | — |
| Intelligent-Tiering | доступ непредсказуем | плата за мониторинг объектов |
| Standard-IA | редкое чтение, бэкапы | ⚠️ retrieval fee, минимум 128 KB на объект, 30 дней |
| Glacier Instant Retrieval | архив с чтением за миллисекунды | минимум 90 дней |
| Glacier Flexible Retrieval | архив | восстановление минуты–12 ч |
| Glacier Deep Archive | долгое хранение (compliance) | восстановление до 12–48 ч |

| Защита | Механизм |
| :--- | :--- |
| Случайное удаление | Versioning (delete marker) |
| Ransomware / удаление админом | Object Lock, режим Compliance |
| Второй слой авторизации + аудит | SSE-KMS с customer managed key (`kms:Decrypt`) |
| Утечка через публичный доступ | Block Public Access на уровне аккаунта |

## RDS, Aurora, DynamoDB, ElastiCache

Подробно: [05_aws_databases_rds.md](./01_theory/05_aws_databases_rds.md).

| Задача | Команда |
| :--- | :--- |
| Инстансы RDS | `aws rds describe-db-instances --query 'DBInstances[].[DBInstanceIdentifier,Engine,DBInstanceStatus,MultiAZ]' --output table` |
| Снапшот | `aws rds create-db-snapshot --db-instance-identifier prod-pg --db-snapshot-identifier prod-pg-20260115` |
| Восстановить в новый инстанс | `aws rds restore-db-instance-from-db-snapshot --db-instance-identifier restored-pg --db-snapshot-identifier prod-pg-20260115` |
| Read replica | `aws rds create-db-instance-read-replica --db-instance-identifier pg-ro --source-db-instance-identifier prod-pg` |
| ⚠️ Тестовый failover Multi-AZ | `aws rds reboot-db-instance --db-instance-identifier prod-pg --force-failover` |
| IAM-токен вместо пароля (15 мин) | `aws rds generate-db-auth-token --hostname <endpoint> --port 5432 --username app` |
| PITR DynamoDB | `aws dynamodb update-continuous-backups --table-name t --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true` |

| Нужно | Выбор |
| :--- | :--- |
| HA, RPO=0 | RDS Multi-AZ (синхронный standby, не читается) |
| Масштаб чтения | Read Replicas (асинхронно, есть lag) |
| Быстрые реплики, клоны, Global DB | Aurora (общий storage, 6 копий в 3 AZ) |
| Key-value, любой масштаб | DynamoDB; PK с высокой кардинальностью (не дата!) |
| Кэш, структуры, failover | ElastiCache Redis/Valkey; подключаться по Primary Endpoint |

## Serverless, EKS, Route53, очереди

Подробно:
[06_aws_serverless_and_managed.md](./01_theory/06_aws_serverless_and_managed.md).

| Задача | Команда |
| :--- | :--- |
| kubeconfig для EKS | `aws eks update-kubeconfig --name my-cluster --region eu-central-1` |
| Версия и статус кластера | `aws eks describe-cluster --name my-cluster --query 'cluster.[version,status]'` |
| Дать IAM-роли доступ к кластеру (access entries, вместо `aws-auth`) | `aws eks create-access-entry --cluster-name my-cluster --principal-arn <role-arn>`<br>`aws eks associate-access-policy --cluster-name my-cluster --principal-arn <role-arn> --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy --access-scope type=cluster` |
| Node groups | `aws eks list-nodegroups --cluster-name my-cluster` |
| ⚠️ Удалить лабораторный кластер | `eksctl delete cluster --name my-cluster` |
| Логин Docker в ECR (12 ч) | `aws ecr get-login-password --region eu-central-1 \| docker login --username AWS --password-stdin <acct>.dkr.ecr.eu-central-1.amazonaws.com` |
| Вызвать Lambda | `aws lambda invoke --function-name f --payload '{}' --cli-binary-format raw-in-base64-out out.json` |
| Хвост логов | `aws logs tail /aws/lambda/f --follow --since 10m` |
| Глубина очереди SQS | `aws sqs get-queue-attributes --queue-url <url> --attribute-names ApproximateNumberOfMessages` |
| Записи зоны Route53 | `aws route53 list-resource-record-sets --hosted-zone-id Z...` |

| Параметр / ограничение | Значение |
| :--- | :--- |
| EKS control plane | $0.10/ч, extended support $0.60/ч |
| Fargate | нет DaemonSet, privileged, доступа к ноде |
| SQS visibility timeout | по умолчанию 30 с; не удалил сообщение → вернётся в очередь |
| SQS long polling | `ReceiveMessageWaitTimeSeconds` до 20 с |
| SQS FIFO | строгий порядок, ~300 msg/s без батчей |
| API Gateway таймаут интеграции | ~29 с; превышение лимитов → HTTP 429 |
| Route53 Alias | на apex-домен (CNAME там нельзя), запросы к AWS-ресурсам бесплатны |
| Route53 failover | скорость = TTL записи (60 с для критичных) |

## Стоимость

| Задача | Команда |
| :--- | :--- |
| Расходы по сервисам за месяц | `aws ce get-cost-and-usage --time-period Start=2026-01-01,End=2026-02-01 --granularity MONTHLY --metrics UnblendedCost --group-by Type=DIMENSION,Key=SERVICE` |
| Свободные Elastic IP (платные) | `aws ec2 describe-addresses --query 'Addresses[?AssociationId==null]'` |
| NAT Gateways | `aws ec2 describe-nat-gateways --query 'NatGateways[].[NatGatewayId,State,SubnetId]'` |

## Симптом → куда смотреть

| Симптом | Куда смотреть |
| :--- | :--- |
| `AccessDenied` | `sts get-caller-identity` (тот ли профиль) → явные Deny, SCP, boundary → resource policy (cross-account) → KMS key policy |
| Таймаут к S3/API из приватной подсети | нет NAT/endpoint, маршрут в route table, SG egress |
| Нет SSH при открытом SG | route table привязана не к той подсети, NACL эфемерные порты, ключ/пользователь, firewall в ОС |
| Инстанс не стартует / не загрузился | `get-console-output`, status checks, user-data в `/var/log/cloud-init-output.log` |
| ASG пересоздаёт инстансы по кругу | grace period, health check путь/порт таргет-группы |
| ALB отвечает 502/503/504 | `describe-target-health`, SG между ALB и таргетами, таймауты приложения |
| Счёт вырос | Cost Explorer по сервисам; NAT GB, cross-AZ трафик, забытые EKS/EBS/EIP |
| Подозрительная активность | CloudTrail (`aws cloudtrail lookup-events`), отключить ключ |

> Проверка: все команды и флаги `aws` сверены с `aws <svc> <op> help`
> (aws-cli 2.37.0), без обращений к API; `eksctl delete cluster --help` —
> через образ `public.ecr.aws/eksctl/eksctl`; не проверено: путь
> SSM-параметра AMI Ubuntu, лимиты и цены (меняются).
