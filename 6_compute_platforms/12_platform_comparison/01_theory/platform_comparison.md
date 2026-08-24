# Сравнение платформ — когда что выбирать

## Матрица выбора

| Критерий | Cloud (AWS/GCP/Azure) | Bare Metal | On-prem Virt (Proxmox/VMware) |
|----------|-----------------------|------------|-------------------------------|
| Time to provision | Минуты | Недели | Часы |
| Capex | $0 | Высокий | Средний |
| Opex при постоянной нагрузке | Высокий | Низкий | Средний |
| Масштабируемость | Почти неограничена | Ограничена железом | Ограничена железом |
| Latency к hardware | Выше (гипервизор) | Минимальная | Средняя (гипервизор) |
| GPU доступность | Любое количество | Только что куплено | Только что куплено |
| Operational complexity | Низкая (managed) | Очень высокая | Высокая |
| Vendor lock-in | Высокий (managed сервисы) | Нет | Средний (VMware) |
| Data sovereignty | Зависит от региона | Полный контроль | Полный контроль |
| Compliance (GDPR, HIPAA) | Возможен | Полный контроль | Полный контроль |
| DR / disaster recovery | Встроен (multi-AZ) | Нужно строить самому | Нужно строить самому |

## Финансовая модель

```
Пример: 100 vCPU, 400 GB RAM, 5 TB storage, постоянная нагрузка

AWS (on-demand):           ~$15,000/мес
AWS (3yr Reserved):        ~$7,000/мес
Bare metal (Hetzner AX102):~$600/мес × 5 серверов = $3,000/мес
On-prem (купить серверы):  ~$100,000 upfront, ~$1,500/мес (power, colo)

Break-even cloud vs bare metal: ~18-24 месяца при постоянной нагрузке

Но: cloud = elastic. Bare metal = fixed. Если нагрузка < 30% → cloud дешевле.
```

## Сценарии и рекомендуемые платформы

### Стартап / MVP

**Рекомендация: Public Cloud (AWS/GCP)**

- Нет капитальных затрат
- Время до market критично
- Нагрузка непредсказуема — можно масштабировать/уменьшать
- Команда маленькая — нет ресурсов управлять железом

### Высокая постоянная нагрузка (50+ серверов 24/7)

**Рекомендация: Hybrid (Cloud + Bare Metal)**

- Bare metal для базовой нагрузки (эффективно)
- Cloud для пиков (burst)
- Hetzner, OVH, Equinix — дешевле AWS при постоянной нагрузке в 3-5×

### GPU для ML training (периодически)

**Рекомендация: Cloud (Spot instances) + локальный bare metal**

- Облако для burst training (AWS p4/p5 Spot, RunPod, Lambda Labs)
- Локальный сервер с потребительскими GPU (RTX 4090) для экспериментов
- Не держать дорогие GPU серверы простаивающими

### Финансы / медицина / госсектор (compliance)

**Рекомендация: On-prem или Private Cloud**

- Data sovereignty — данные не покидают периметр
- Compliance требует полный аудит доступа к железу
- Proxmox или VMware + OpenStack

### Enterprise с существующим vSphere

**Рекомендация: Hybrid (vSphere + Cloud)**

- Не выбрасывать инвестиции в vSphere
- Новые сервисы в облаке
- Постепенная миграция на k8s (KubeVirt или Konveyor)

## Производительность — ключевые различия

```
Latency (P99, простой HTTP):
  Bare metal:            < 1ms (внутри сервера)
  On-prem VM:            1-2ms
  Cloud VM same AZ:      2-5ms
  Cloud VM cross-AZ:     1-3ms
  Cloud VM cross-region: 50-300ms

Disk I/O:
  NVMe bare metal:       7 GB/s sequential, 1M IOPS
  Cloud gp3:             1 GB/s, 16000 IOPS
  Cloud io2:             4 GB/s, 256000 IOPS (дорого)

Network:
  Bare metal 100GbE:     12 GB/s
  Cloud (c5n.18xlarge):  25 Gbps = 3 GB/s (дорого)
  Cloud standard:        1-10 Gbps
```

## Рекомендации по выбору

1. **Начинать всегда с облака** — проверь спрос, потом оптимизируй
2. **Bare metal** — только когда понятна постоянная нагрузка и есть команда для ops
3. **On-prem virt** — если уже есть инвестиции или compliance требует
4. **Hybrid** — для зрелых компаний с чёткими требованиями к каждой части
5. **Managed > self-managed** — не управляй PostgreSQL если есть RDS, не управляй k8s если есть EKS
