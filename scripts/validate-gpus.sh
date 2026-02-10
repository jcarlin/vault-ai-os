#!/bin/bash
# scripts/validate-gpus.sh
# Comprehensive GPU detection and health validation

set -e

echo "=== GPU Detection Validation ==="
echo ""

# Check if nvidia-smi exists
if ! command -v nvidia-smi &> /dev/null; then
    echo "ERROR: nvidia-smi not found. NVIDIA drivers not installed."
    exit 1
fi

# Check GPU count
GPU_COUNT=$(nvidia-smi --query-gpu=count --format=csv,noheader | head -1)
echo "✓ GPU Count: $GPU_COUNT"

if [ -z "$GPU_COUNT" ] || [ "$GPU_COUNT" -eq 0 ]; then
    echo "ERROR: No GPUs detected"
    exit 1
fi

# Check GPU names and memory
echo ""
echo "=== GPU Information ==="
nvidia-smi --query-gpu=index,name,memory.total --format=csv
echo ""

# Check temperatures
echo "=== GPU Temperatures ==="
nvidia-smi --query-gpu=index,temperature.gpu --format=csv
MAX_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader | sort -nr | head -1)
echo ""
echo "Max GPU Temperature: ${MAX_TEMP}°C"

if [ "$MAX_TEMP" -gt 85 ]; then
    echo "WARNING: GPU temperature >85°C (thermal throttling may occur)"
elif [ "$MAX_TEMP" -gt 60 ]; then
    echo "NOTE: GPU temperature >60°C at idle (check cooling)"
else
    echo "✓ GPU temperatures normal"
fi
echo ""

# Check PCIe link speed
echo "=== PCIe Link Status ==="
nvidia-smi --query-gpu=index,pcie.link.gen.current,pcie.link.width.current --format=csv
echo ""

# Check CUDA version
echo "=== CUDA Toolkit ==="
if command -v nvcc &> /dev/null; then
    CUDA_VERSION=$(nvcc --version | grep "release" | sed 's/.*release \([0-9.]*\).*/\1/')
    echo "CUDA Version: $CUDA_VERSION"

    if [[ "$CUDA_VERSION" == 12.8* ]]; then
        echo "✓ CUDA 12.8 confirmed (required for RTX 5090)"
    elif [[ "$CUDA_VERSION" == 12.* ]]; then
        echo "⚠ CUDA $CUDA_VERSION detected (RTX 5090 requires CUDA 12.8)"
    else
        echo "⚠ CUDA $CUDA_VERSION detected (expected 12.8 for RTX 5090)"
    fi
else
    echo "WARNING: nvcc not found (CUDA toolkit may not be in PATH)"
fi
echo ""

# Check kernel version
echo "=== Kernel Version ==="
KERNEL_VERSION=$(uname -r)
echo "Kernel: $KERNEL_VERSION"

if [[ "$KERNEL_VERSION" == 6.13.* ]] || [[ "$KERNEL_VERSION" > "6.13" ]]; then
    echo "✓ Kernel 6.13+ confirmed (required for RTX 5090/Blackwell)"
elif [[ "$KERNEL_VERSION" == 6.8.* ]] || [[ "$KERNEL_VERSION" < "6.13" ]]; then
    echo "⚠ Kernel $KERNEL_VERSION detected (RTX 5090 requires 6.13+)"
else
    echo "✓ Kernel version acceptable"
fi
echo ""

# Check driver version
echo "=== Driver Version ==="
DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1)
echo "NVIDIA Driver: $DRIVER_VERSION"
echo ""

# Check for GPU errors in dmesg
echo "=== System Logs Check ==="
GPU_ERRORS=$(dmesg | grep -i nvidia | grep -i error | wc -l)
if [ "$GPU_ERRORS" -gt 0 ]; then
    echo "WARNING: Found $GPU_ERRORS GPU errors in dmesg"
    echo "Recent errors:"
    dmesg | grep -i nvidia | grep -i error | tail -5
else
    echo "✓ No GPU errors in system logs"
fi
echo ""

# GPU utilization and processes
echo "=== Current GPU Utilization ==="
nvidia-smi --query-gpu=index,utilization.gpu,utilization.memory --format=csv
echo ""

echo "=== Running GPU Processes ==="
nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv
echo ""

# Summary
echo "==================================="
echo "=== GPU Validation Complete ==="
echo "==================================="
echo "GPUs detected: $GPU_COUNT"
echo "Driver version: $DRIVER_VERSION"
echo "Max temperature: ${MAX_TEMP}°C"
echo "Errors found: $GPU_ERRORS"
echo ""

if [ "$GPU_ERRORS" -eq 0 ] && [ "$MAX_TEMP" -lt 85 ]; then
    echo "✓ All checks passed"
    exit 0
else
    echo "⚠ Some warnings detected (see above)"
    exit 0
fi
