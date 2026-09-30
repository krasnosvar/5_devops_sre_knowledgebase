# Multi-Cloud и Hybrid

## Hybrid Cloud — on-prem + облако

**Типичные паттерны:**

**Lift and shift** — перенести VM как есть в облако. Быстро, без оптимизации.
Плюс: скорость. Минус: не используешь преимущества облака, часто дороже.

**Cloud Bursting** — базовая нагрузка on-prem, пики — в облако.
On-prem: постоянные 100 серверов. Cloud: +200 серверов в Black Friday.
Требует: единая сеть (VPN/Direct Connect), общие образы.

**Data Gravity** — данные остаются on-prem, вычисления в облаке.
Актуально при compliance требованиях (данные не покидают страну).

**DR (Disaster Recovery) в облаке** — on-prem primary, cloud secondary.
RTO/RPO определяют архитектуру: pilot light, warm standby, active-active.

## Сетевая связность

```bash
# AWS Direct Connect — выделенный канал on-prem → AWS (1/10 Gbps)
# Дорого, но: низкая latency, предсказуемая пропускная способность, без интернета

# AWS Site-to-Site VPN — IPSec туннель через интернет
aws ec2 create-vpn-connection \
  --type ipsec.1 \
  --customer-gateway-id cgw-xxx \
  --vpn-gateway-id vgw-xxx

# GCP Dedicated Interconnect — аналог Direct Connect
# Azure ExpressRoute — аналог Direct Connect

# Для лабы: Wireguard туннель
# Быстро поднимается, работает поверх любого интернета
```

## Kubernetes в hybrid — Federation и Multi-cluster

```bash
# Один ArgoCD управляет кластерами в разных местах
argocd cluster add production-aws    # EKS кластер
argocd cluster add production-onprem # on-prem кластер

# ApplicationSet деплоит в оба
spec:
  generators:
    - clusters: {}   # все зарегистрированные кластеры
```

```yaml
# Cilium Cluster Mesh — сетевая связность между кластерами
# Pod из кластера A видит Pod из кластера B по имени Service
cilium clustermesh enable --context cluster-aws
cilium clustermesh enable --context cluster-onprem
cilium clustermesh connect --context cluster-aws --destination-context cluster-onprem
```

## Multi-Cloud — несколько облаков

**Почему компании используют multi-cloud:**
- Регуляторные требования (разные данные в разных регионах/провайдерах)
- Best-of-breed: GCP для AI, AWS для основной инфраструктуры
- Vendor lock-in минимизация
- Переговорная позиция с провайдерами

**Почему НЕ нужен multi-cloud (чаще всего):**
- Операционная сложность ×2
- Дублирование экспертизы команды
- Интеграции между облаками стоят денег (egress)
- «Избегание vendor lock-in» — часто иллюзия (всё равно используешь managed сервисы)

**Когда оправдан:**
- Реальные compliance требования
- Приобретение компании с другим облаком
- Специфические сервисы (BigQuery + AWS остальное)
- Зрелая платформенная команда

## Terraform для multi-cloud

```hcl
# Один Terraform код — несколько провайдеров
terraform {
  required_providers {
    aws   = { source = "hashicorp/aws" }
    google = { source = "hashicorp/google" }
    azurerm = { source = "hashicorp/azurerm" }
  }
}

provider "aws" { region = "eu-central-1" }
provider "google" { project = "my-project" region = "europe-west3" }

# DNS в Route53 + compute в GCP
resource "google_compute_instance" "app" { ... }

resource "aws_route53_record" "app" {
  records = [google_compute_instance.app.network_interface[0].access_config[0].nat_ip]
}
```

## Единая Observability для hybrid/multi-cloud

```
On-prem Prometheus → remote_write → VictoriaMetrics (облако)
AWS CloudWatch → CloudWatch Exporter → VictoriaMetrics
GCP Monitoring → ... → VictoriaMetrics

Grafana → единый дашборд для всех источников
```

Альтернативы:
- **Datadog** — commercial, native multi-cloud agent
- **New Relic** — commercial
- **Grafana Cloud** — managed Grafana + Prometheus + Loki

## Стоимость — egress charges

Главная скрытая стоимость multi-cloud и hybrid:

```
Данные внутри региона AWS: бесплатно
Данные между AZ AWS: ~$0.01/GB
Данные из AWS в интернет: ~$0.09/GB
Данные из AWS → GCP: ~$0.09/GB (egress) + GCP ingress

Для петабайт это существенно. Считай заранее.
```
