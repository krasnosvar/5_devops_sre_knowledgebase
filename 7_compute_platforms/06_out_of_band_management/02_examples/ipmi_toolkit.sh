#!/usr/bin/env bash
# ipmitool шпаргалка — управление серверами через IPMI/BMC

BMC_HOST="${BMC_HOST:-192.168.1.100}"
BMC_USER="${BMC_USER:-admin}"
BMC_PASS="${BMC_PASS:-admin}"

IPMI="ipmitool -H $BMC_HOST -U $BMC_USER -P $BMC_PASS -I lanplus"

echo "=== Статус питания ==="
$IPMI chassis power status

echo -e "\n=== Сенсоры температуры ==="
$IPMI sdr type Temperature 2>/dev/null | head -10

echo -e "\n=== Вентиляторы ==="
$IPMI sdr type Fan 2>/dev/null | head -10

echo -e "\n=== Потребление питания ==="
$IPMI dcmi power reading 2>/dev/null || $IPMI sdr type "Power Supply" 2>/dev/null | head -5

echo -e "\n=== System Event Log (последние события) ==="
$IPMI sel list 2>/dev/null | tail -10

echo -e "\n=== Информация о системе ==="
$IPMI fru print 2>/dev/null | grep -E "Product Name|Serial|Part Number" | head -5

# ── Управление питанием ───────────────────────────────────────────────────────
power_on()     { $IPMI chassis power on;     }
power_off()    { $IPMI chassis power off;    }
power_cycle()  { $IPMI chassis power cycle;  }
power_reset()  { $IPMI chassis power reset;  }
graceful_off() { $IPMI chassis power soft;   }  # ACPI shutdown

# ── Настройка boot ────────────────────────────────────────────────────────────
boot_pxe()    { $IPMI chassis bootdev pxe;  $IPMI chassis power on; }
boot_disk()   { $IPMI chassis bootdev disk; }
boot_bios()   { $IPMI chassis bootdev bios; }

# ── Serial Over LAN ───────────────────────────────────────────────────────────
sol_connect() {
    $IPMI -I lanplus sol activate
    # Выход: Enter → ~.
}

# ── Redfish API (современная альтернатива IPMI) ───────────────────────────────
redfish_status() {
    local host=$1 user=$2 pass=$3
    curl -sk -u "$user:$pass" \
        "https://$host/redfish/v1/Systems/System.Embedded.1" \
        | jq '{Model, PowerState, MemoryGB: .MemorySummary.TotalSystemMemoryGiB}'
}

echo -e "\nФункции: power_on, power_off, power_cycle, boot_pxe, boot_disk, sol_connect"
echo "Redfish: redfish_status <host> <user> <pass>"
