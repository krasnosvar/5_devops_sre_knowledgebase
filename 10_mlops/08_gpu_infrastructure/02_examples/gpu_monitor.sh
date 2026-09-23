#!/usr/bin/env bash
# Мониторинг GPU — NVIDIA, AMD, Intel Arc

echo "=== GPU информация ==="

# ── NVIDIA ────────────────────────────────────────────────────────────────────
if command -v nvidia-smi &>/dev/null; then
    echo "--- NVIDIA ---"
    nvidia-smi --query-gpu=name,memory.total,memory.free,temperature.gpu,utilization.gpu,power.draw \
        --format=csv,noheader,nounits 2>/dev/null \
        | awk -F', ' '{printf "GPU: %-30s | VRAM: %s/%s MB | Temp: %s°C | Util: %s%% | Power: %sW\n",
            $1, $2-$3, $2, $4, $5, $6}' \
        || nvidia-smi

    echo -e "\nRunning processes on GPU:"
    nvidia-smi --query-compute-apps=pid,process_name,used_memory \
        --format=csv,noheader 2>/dev/null || echo "(no processes)"
fi

# ── AMD ───────────────────────────────────────────────────────────────────────
if command -v rocm-smi &>/dev/null; then
    echo "--- AMD ROCm ---"
    rocm-smi --showproductname --showuse --showmeminfo vram --showtemp 2>/dev/null
fi

# ── Intel Arc ─────────────────────────────────────────────────────────────────
if command -v intel_gpu_top &>/dev/null; then
    echo "--- Intel Arc (1 second snapshot) ---"
    timeout 1 intel_gpu_top -J 2>/dev/null | jq '{
        gpu_util: .engines."Render/3D".busy,
        video_util: .engines.Video.busy
    }' 2>/dev/null || echo "(intel_gpu_top requires root or video group)"
fi

# ── К8s GPU ───────────────────────────────────────────────────────────────────
echo -e "\n=== GPU в Kubernetes ==="
if command -v kubectl &>/dev/null; then
    echo "Ноды с GPU:"
    kubectl get nodes \
        -o custom-columns='NAME:.metadata.name,NVIDIA:.status.capacity.nvidia\.com/gpu,AMD:.status.capacity.amd\.com/gpu' \
        2>/dev/null | grep -v "<none>"

    echo "Pods использующие GPU:"
    kubectl get pods -A -o json 2>/dev/null \
        | jq -r '.items[] |
            .metadata as $m |
            .spec.containers[] |
            select(.resources.limits."nvidia.com/gpu" or .resources.limits."amd.com/gpu") |
            "\($m.namespace)\t\($m.name)\t\(.resources.limits."nvidia.com/gpu" // .resources.limits."amd.com/gpu") GPU"' \
        | column -t
fi

# ── DCGM Exporter метрики ─────────────────────────────────────────────────────
echo -e "\n=== DCGM Exporter (Prometheus metrics) ==="
if curl -sf http://localhost:9400/metrics &>/dev/null; then
    echo "DCGM metrics available at http://localhost:9400/metrics"
    curl -sf http://localhost:9400/metrics 2>/dev/null \
        | grep -E "DCGM_FI_DEV_GPU_UTIL|DCGM_FI_DEV_FB_USED|DCGM_FI_DEV_GPU_TEMP|DCGM_FI_DEV_POWER_USAGE" \
        | head -10
else
    echo "(DCGM Exporter не запущен — helm install dcgm-exporter nvidia/dcgm-exporter)"
fi
