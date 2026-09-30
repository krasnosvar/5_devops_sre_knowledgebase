#!/usr/bin/env bash
# Автоматическая инвентаризация сервера — собрать hardware info в JSON

set -euo pipefail

OUTPUT="${1:-/tmp/inventory-$(hostname)-$(date +%Y%m%d).json}"

gather_info() {
    python3 - <<'PYEOF'
import json, subprocess, os, platform

def run(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True, stderr='/dev/null').strip()
    except:
        return "unknown"

info = {
    "hostname": platform.node(),
    "os": {
        "system": platform.system(),
        "release": platform.release(),
        "version": platform.version(),
        "arch": platform.machine()
    },
    "cpu": {
        "model": run("grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2"),
        "cores_physical": run("grep 'cpu cores' /proc/cpuinfo | head -1 | awk '{print $4}'"),
        "threads": run("nproc"),
        "sockets": run("grep 'physical id' /proc/cpuinfo | sort -u | wc -l")
    },
    "memory": {
        "total_gb": run("awk '/MemTotal/ {printf \"%.1f\", $2/1024/1024}' /proc/meminfo"),
        "available_gb": run("awk '/MemAvailable/ {printf \"%.1f\", $2/1024/1024}' /proc/meminfo"),
        "type": run("dmidecode -t memory 2>/dev/null | grep 'Type:' | grep -v Unknown | head -1 | awk '{print $2}'")
    },
    "disks": [],
    "network": [],
    "serial": run("dmidecode -s system-serial-number 2>/dev/null"),
    "product": run("dmidecode -s system-product-name 2>/dev/null"),
    "manufacturer": run("dmidecode -s system-manufacturer 2>/dev/null"),
    "bios_version": run("dmidecode -s bios-version 2>/dev/null")
}

# Диски
for disk in run("lsblk -dn -o NAME").split():
    info["disks"].append({
        "name": disk,
        "size": run(f"lsblk -dn -o SIZE /dev/{disk}"),
        "type": "SSD" if run(f"cat /sys/block/{disk}/queue/rotational") == "0" else "HDD",
        "model": run(f"cat /sys/block/{disk}/device/model 2>/dev/null")
    })

# Сетевые интерфейсы
for iface in os.listdir("/sys/class/net"):
    if iface == "lo":
        continue
    info["network"].append({
        "name": iface,
        "mac": run(f"cat /sys/class/net/{iface}/address"),
        "speed": run(f"cat /sys/class/net/{iface}/speed 2>/dev/null") + " Mbps",
        "state": run(f"cat /sys/class/net/{iface}/operstate")
    })

print(json.dumps(info, indent=2))
PYEOF
}

echo "Collecting hardware inventory for $(hostname)..."
gather_info > "$OUTPUT"
echo "Inventory saved to: $OUTPUT"
cat "$OUTPUT"
