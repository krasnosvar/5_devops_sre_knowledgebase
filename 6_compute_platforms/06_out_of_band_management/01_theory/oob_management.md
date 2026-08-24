# Out-of-Band Management — управление серверами без ОС

## Что такое BMC и зачем нужен

BMC (Baseboard Management Controller) — отдельный микроконтроллер на материнской плате.
Работает независимо от основного CPU и ОС. Имеет собственный сетевой порт (dedicated или shared).

**Что позволяет делать:**
- Включить/выключить/перезагрузить сервер (даже если ОС зависла)
- Подключиться к KVM (клавиатура/видео/мышь) удалённо — как сидеть за сервером
- Смотреть логи POST (загрузки), serial console
- Обновить BIOS/UEFI firmware без физического доступа
- Мониторить температуры, вентиляторы, питание
- Настроить PXE boot для автоматической установки ОС

## Названия BMC у разных вендоров

| Вендор | Название |
|--------|---------|
| Dell | iDRAC (integrated Dell Remote Access Controller) |
| HP / HPE | iLO (integrated Lights-Out) |
| Supermicro | IPMI / BMC |
| Lenovo | XCC (XClarity Controller) |
| Intel | BMC (разные поколения) |
| Fujitsu | iRMC |

## IPMI — протокол для управления BMC

IPMI (Intelligent Platform Management Interface) — стандарт протокола.
Работает на порту 623 UDP/TCP.

```bash
# установка ipmitool
dnf install ipmitool    # Fedora/RHEL
apt install ipmitool    # Ubuntu

# управление питанием
ipmitool -H 192.168.1.100 -U admin -P password chassis power status
ipmitool -H 192.168.1.100 -U admin -P password chassis power on
ipmitool -H 192.168.1.100 -U admin -P password chassis power off
ipmitool -H 192.168.1.100 -U admin -P password chassis power reset
ipmitool -H 192.168.1.100 -U admin -P password chassis power cycle  # выкл+вкл

# Serial Over LAN (SOL) — serial console через сеть
ipmitool -H 192.168.1.100 -U admin -P password -I lanplus sol activate
# выход: Enter ~.

# сенсоры
ipmitool -H 192.168.1.100 -U admin -P password sdr type Temperature
ipmitool -H 192.168.1.100 -U admin -P password sdr type Fan
ipmitool -H 192.168.1.100 -U admin -P password sensor list

# логи System Event Log
ipmitool -H 192.168.1.100 -U admin -P password sel list
ipmitool -H 192.168.1.100 -U admin -P password sel clear

# network boot (PXE) для следующего boot
ipmitool -H 192.168.1.100 -U admin -P password chassis bootdev pxe
ipmitool -H 192.168.1.100 -U admin -P password chassis bootdev disk  # вернуть назад
```

## Redfish — современный HTTP API

Redfish — замена IPMI. REST API поверх HTTPS.
Все современные серверы (2015+) поддерживают Redfish.

```bash
# базовый endpoint
curl -sk -u admin:password https://192.168.1.100/redfish/v1/ | jq .

# информация о системе
curl -sk -u admin:password https://192.168.1.100/redfish/v1/Systems/System.Embedded.1 | jq '{
  Model: .Model,
  Manufacturer: .Manufacturer,
  SerialNumber: .SerialNumber,
  PowerState: .PowerState,
  ProcessorCount: .ProcessorSummary.Count,
  MemoryGB: .MemorySummary.TotalSystemMemoryGiB
}'

# список дисков
curl -sk -u admin:password \
  https://192.168.1.100/redfish/v1/Systems/System.Embedded.1/Storage | jq .

# управление питанием
curl -sk -u admin:password \
  -X POST https://192.168.1.100/redfish/v1/Systems/System.Embedded.1/Actions/ComputerSystem.Reset \
  -H "Content-Type: application/json" \
  -d '{"ResetType": "ForceRestart"}'

# возможные ResetType: On, ForceOff, GracefulShutdown, ForceRestart, Nmi
```

## iDRAC (Dell) — специфика

```bash
# Dell-специфичные команды через racadm (в ОС или через SSH к iDRAC)
# SSH к iDRAC
ssh admin@192.168.1.100

# внутри iDRAC SSH сессии:
racadm getsvctag               # service tag (для поддержки Dell)
racadm getsysinfo              # общая информация
racadm set iDRAC.IPv4.Address 192.168.1.101   # изменить IP iDRAC
racadm jobqueue view           # задачи (обновление firmware и т.д.)

# обновление firmware через racadm
racadm update -f firmware.exe -e localhost -u admin -p password
```

## iLO (HP/HPE) — специфика

```bash
# SSH к iLO
ssh administrator@192.168.1.100

# HPE iLOrest
ilorest login 192.168.1.100 -u administrator -p password
ilorest get --select ComputerSystem. --json
ilorest get --select Thermal. --json  # температуры
ilorest logout
```

## Мониторинг через IPMI Exporter (Prometheus)

```yaml
# docker-compose: IPMI Exporter для Prometheus
services:
  ipmi-exporter:
    image: prometheuscommunity/ipmi-exporter:latest
    ports:
      - "9290:9290"
    volumes:
      - ./ipmi_config.yaml:/config.yml:ro
    command: --config.file=/config.yml
```

```yaml
# ipmi_config.yaml
modules:
  default:
    user: admin
    password: password
    privilege: user
    collectors:
      - bmc
      - ipmi
      - chassis
      - dcmi
```

```yaml
# prometheus.yml scrape config
- job_name: 'ipmi'
  params:
    module: [default]
  static_configs:
    - targets:
      - 192.168.1.100   # IPMI адрес сервера 1
      - 192.168.1.101   # IPMI адрес сервера 2
  relabel_configs:
    - source_labels: [__address__]
      target_label: __param_target
    - source_labels: [__param_target]
      target_label: instance
    - target_label: __address__
      replacement: ipmi-exporter:9290
```
