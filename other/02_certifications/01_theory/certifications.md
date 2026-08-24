# Сертификации DevOps / SRE / Cloud

## Обзор сертификаций по уровням

### Kubernetes

**CKA (Certified Kubernetes Administrator)** — самая ценная k8s сертификация.
- Формат: практический экзамен в терминале (2 часа), задачи в реальном кластере
- Темы: cluster setup, workloads, services, networking, storage, security, troubleshooting
- Стоимость: $395 (включает одну повторную попытку)
- Подготовка: [Killer.sh simulator](https://killer.sh) + Killercoda CKA scenarios

**CKAD (Certified Kubernetes Application Developer)**
- Для разработчиков, не администраторов
- Темы: Pod design, configuration, multi-container, observability, services, state
- Стоимость: $395

**CKS (Certified Kubernetes Security Specialist)**
- Требует действующий CKA
- Темы: cluster hardening, system hardening, supply chain security, monitoring, runtime security
- Стоимость: $395

### AWS

**AWS Solutions Architect Associate (SAA-C03)**
- Самая популярная AWS сертификация
- Формат: 65 вопросов с множественным выбором, 130 минут
- Темы: compute, storage, database, networking, security, cost optimization
- Стоимость: $300
- Лучший курс: [Adrian Cantrill](https://learn.cantrill.io/) или Stephane Maarek (Udemy)

**AWS DevOps Engineer Professional (DOP-C02)**
- Requires: SAA или SysOps Associate
- Темы: CI/CD pipelines, IaC (CloudFormation), monitoring, incident management
- Стоимость: $300

**AWS SysOps Administrator Associate**
- Операционная работа: мониторинг, автоматизация, Storage, HA

### HashiCorp / Terraform

**Terraform Associate (003)**
- Базовое понимание Terraform
- Формат: 57 вопросов, 60 минут, онлайн
- Стоимость: $70.50
- Подготовка: [официальные tutorials](https://developer.hashicorp.com/terraform/tutorials/certification-003)

### Linux

**LFCS (Linux Foundation Certified System Administrator)**
- Практический экзамен на работающей системе
- Темы: essential commands, файловая система, пользователи, сервисы, сеть
- Стоимость: $395

**RHCSA (Red Hat Certified System Administrator)**
- Для RHEL/Fedora администраторов
- Практический экзамен
- Стоимость: $400

## Стратегия подготовки

### CKA (пример)

```
Неделя 1-2: Теория
  - Kubernetes docs: Concepts раздел
  - Kubernetes in Action (книга)
  
Неделя 3-4: Практика
  - Killercoda CKA scenarios: https://killercoda.com/killer-shell-cka
  - Поднять кластер kubeadm локально (KVM или k8s-the-hard-way)

Неделя 5-6: Mock exams
  - Killer.sh simulator (2 сессии включены в экзамен)
  - https://www.udemy.com/course/certified-kubernetes-administrator/

За день до экзамена:
  - Прочитать kubernetes.io/docs shorturl list
  - Убедиться что знаешь alias k=kubectl и экспортировать его первым делом
```

### Полезные alias на экзамене CKA

```bash
# первые команды на экзамене CKA
alias k=kubectl
export do="--dry-run=client -o yaml"
export now="--force --grace-period 0"

# быстрое создание ресурсов
k run nginx --image=nginx $do > pod.yaml
k create deployment nginx --image=nginx --replicas=3 $do > deploy.yaml
k create service clusterip nginx --tcp=80:80 $do > svc.yaml

# autocomplete (важно!)
source <(kubectl completion bash)
complete -F __start_kubectl k
```

## ROI — что реально даёт

| Сертификат | Рост зарплаты | Ценность для работодателя |
|-----------|---------------|--------------------------|
| CKA | +10-20% | Высокая (практический экзамен = реальные навыки) |
| AWS SAA | +5-15% | Средняя (много "бумажных" кандидатов) |
| Terraform Associate | +5% | Низкая (слишком лёгкий) |
| CKAD | +5-10% | Средняя |
| CKS | +15-25% | Высокая (редкая, требует CKA) |

**Важнее сертификации:** реальные проекты в GitHub, contribution в open-source, написанные посты/статьи.

## Платформы для практики

- [Killercoda](https://killercoda.com/) — бесплатные k8s labs в браузере
- [Killer.sh](https://killer.sh/) — simulator экзамена CKA/CKAD/CKS (платный, ~$30)
- [KodeKloud](https://kodekloud.com/) — практические курсы с labs
- [Play with Kubernetes](https://labs.play-with-k8s.com/) — бесплатный playground
- [AWS Skill Builder](https://skillbuilder.aws/) — бесплатные AWS labs
