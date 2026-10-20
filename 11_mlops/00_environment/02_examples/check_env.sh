#!/usr/bin/env bash
# Диагностика локального окружения для MLOps + LLMOps (CPU / iGPU стенд)
set -euo pipefail

echo "=== 1. Модель процессора и топология ядер (P-cores vs E-cores) ==="
lscpu | grep -E "Model name|CPU\(s\):|Thread\(s\) per core|Core\(s\) per socket" || true
echo ""
echo "Распределение максимальных частот по логическим потокам (первые 14):"
lscpu -e=CPU,CORE,MAXMHZ | head -n 15

echo ""
echo "=== 2. Оперативная память и доступный запас под модели ==="
free -h

echo ""
echo "=== 3. Встроенная графика / ускорители (DRI / Intel Arc / NPU) ==="
if [ -d /dev/dri ]; then
    ls -la /dev/dri/
else
    echo "/dev/dri не найден (только CPU-режим)"
fi

echo ""
echo "=== 4. Инструменты Python, uv и контейнеризации ==="
for cmd in python3 uv docker kubectl k3d; do
    if command -v "$cmd" >/dev/null 2>&1; then
        if [ "$cmd" = "kubectl" ]; then
            ver="$("$cmd" version --client 2>&1 | head -n 1)"
        else
            ver="$("$cmd" --version 2>&1 | head -n 1)"
        fi
        printf "  [OK] %-10s -> %s\n" "$cmd" "$ver"
    else
        printf "  [--] %-10s -> не установлен\n" "$cmd"
    fi
done

echo ""
echo "=== 5. Единый каталог кэша моделей ==="
CACHE_DIR="${MLOPS_CACHE_DIR:-$HOME/.cache/mlops-models}"
mkdir -p "$CACHE_DIR"/{hf,gguf,ollama,onnx,torch}
echo "  Каталог кэша готов: $CACHE_DIR"
df -h "$CACHE_DIR" | tail -n 1 | awk '{print "  Свободно на диске: " $4 " из " $2}'
