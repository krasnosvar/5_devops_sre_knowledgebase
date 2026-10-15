# AWS CLI — частые команды

Справочник команд для чтения и копирования по одной, а не скрипт для
запуска целиком. Раньше этот файл был исполняемым `.sh`: запуск «как
скрипта» создал бы инстанс и тут же попытался бы удалить другой.

> **Внимание.** Команды ниже работают с реальным аккаунтом AWS и реальными
> деньгами. Перед выполнением:
> - проверьте, в какой аккаунт и регион вы смотрите:
>   `aws sts get-caller-identity` и `aws configure get region`;
> - замените заглушки (`i-xxx`, `sg-xxx`, `my-bucket` и т.п.) на свои
>   значения — не копируйте блок целиком;
> - для команд EC2, которые что-то создают или удаляют, сначала выполните
>   их с флагом `--dry-run`: он проверяет права и параметры, ничего не
>   меняя (при успехе AWS ответит ошибкой `DryRunOperation`).

## EC2

Список инстансов (только чтение):

```bash
aws ec2 describe-instances \
    --query 'Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,PublicIpAddress,Tags[?Key==`Name`]|[0].Value]' \
    --output table
```

Запустить инстанс (создаёт платный ресурс; AMI ID зависит от региона и
устаревает — актуальный ищите через `aws ec2 describe-images` или SSM
Parameter Store):

```bash
aws ec2 run-instances --dry-run \
    --image-id ami-0c7af5f9b3b0de3e4 \
    --instance-type t3.micro \
    --key-name my-key \
    --security-group-ids sg-xxx \
    --subnet-id subnet-xxx \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=test}]'
```

Остановить и запустить инстанс:

```bash
aws ec2 stop-instances --instance-ids i-xxx
aws ec2 start-instances --instance-ids i-xxx
```

> **Опасно: необратимо.** `terminate-instances` удаляет инстанс навсегда,
> вместе с root-томом EBS (если у него `DeleteOnTermination=true`, это
> поведение по умолчанию). Сначала проверьте, что ID тот самый:
> `aws ec2 describe-instances --instance-ids i-xxx`, затем `--dry-run`.
> Для важных инстансов включайте защиту:
> `aws ec2 modify-instance-attribute --instance-id i-xxx
> --disable-api-termination`.

```bash
aws ec2 terminate-instances --dry-run --instance-ids i-xxx
aws ec2 terminate-instances --instance-ids i-xxx
```

## S3

```bash
aws s3 ls                               # список bucket'ов
aws s3 ls s3://my-bucket/prefix/        # содержимое
aws s3 cp file.txt s3://my-bucket/      # загрузить
aws s3 presign s3://my-bucket/file.pdf --expires-in 3600  # presigned URL
```

> **Опасно.** `sync --delete` удаляет в назначении всё, чего нет в
> источнике. Перепутанные местами аргументы стирают данные. Сначала
> запустите с `--dryrun` и прочитайте список операций.

```bash
aws s3 sync ./local/ s3://my-bucket/remote/ --delete --dryrun
aws s3 sync ./local/ s3://my-bucket/remote/ --delete
```

## IAM

```bash
aws iam get-user                        # текущий IAM-пользователь
aws iam list-attached-user-policies --user-name my-user

# Проверить, разрешены ли действия (ничего не меняет)
aws iam simulate-principal-policy \
    --policy-source-arn arn:aws:iam::123456789012:user/my-user \
    --action-names s3:GetObject s3:PutObject \
    --resource-arns 'arn:aws:s3:::my-bucket/*'
```

`get-user` без аргументов работает только для IAM-пользователя; под
ролью (SSO, EC2 instance profile) используйте `aws sts
get-caller-identity`.

## EKS

```bash
aws eks list-clusters
aws eks update-kubeconfig --name my-cluster --region eu-central-1
aws eks describe-cluster --name my-cluster \
    --query 'cluster.{version:version,status:status}'
```

Помните: control plane EKS платный (почасовая оплата за каждый кластер,
см. [06_aws_serverless_and_managed.md](../01_theory/06_aws_serverless_and_managed.md)),
даже если в кластере нет ни одной ноды.

## Затраты

Расходы по сервисам за месяц, только строки дороже 10 USD (`Amount`
приходит строкой, поэтому нужен `to_number`):

```bash
aws ce get-cost-and-usage \
    --time-period Start=2024-01-01,End=2024-02-01 \
    --granularity MONTHLY \
    --metrics UnblendedCost \
    --group-by Type=DIMENSION,Key=SERVICE \
    --query 'ResultsByTime[0].Groups[?to_number(Metrics.UnblendedCost.Amount) > `10`].[Keys[0],Metrics.UnblendedCost.Amount]' \
    --output table
```

Каждый вызов Cost Explorer API платный (порядка центов за запрос) — не
ставьте его в цикл.

Найти неподключённые EBS-тома (только чтение; удаление — отдельное
осознанное действие после проверки снапшотов):

```bash
aws ec2 describe-volumes \
    --filters Name=status,Values=available \
    --query 'Volumes[*].[VolumeId,Size,AvailabilityZone,CreateTime]' \
    --output table
```
