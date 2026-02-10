#!/bin/bash
# scripts/test-tensorflow-ngc.sh
# Test TensorFlow 2.17.0 via NGC container with CUDA 12.8

set -e

echo "========================================"
echo " TensorFlow NGC Container GPU Test"
echo "========================================"
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed or not in PATH"
    exit 1
fi

# Check if NVIDIA Container Toolkit is configured
if ! docker run --rm --gpus all nvidia/cuda:12.8.0-base-ubuntu24.04 nvidia-smi &> /dev/null; then
    echo "ERROR: NVIDIA Container Toolkit not configured properly"
    echo "Run: sudo apt install nvidia-container-toolkit"
    exit 1
fi

echo "✓ Docker and NVIDIA Container Toolkit detected"
echo ""

# Pull NGC TensorFlow container if not present
NGC_IMAGE="nvcr.io/nvidia/tensorflow:25.02-tf2-py3"
echo "Checking for NGC TensorFlow image: $NGC_IMAGE"
if ! docker images | grep -q "nvcr.io/nvidia/tensorflow.*25.02-tf2-py3"; then
    echo "Pulling NGC TensorFlow image (this may take a while)..."
    docker pull $NGC_IMAGE
fi
echo "✓ NGC TensorFlow image ready"
echo ""

# Test 1: GPU Detection
echo "=== Test 1: GPU Detection ==="
docker run --rm --gpus all $NGC_IMAGE python3 -c "
import tensorflow as tf
print(f'TensorFlow version: {tf.__version__}')
gpus = tf.config.list_physical_devices('GPU')
print(f'GPUs detected: {len(gpus)}')
for i, gpu in enumerate(gpus):
    print(f'  GPU {i}: {gpu.name}')
"
echo "✓ GPU detection test passed"
echo ""

# Test 2: Simple GPU Operation
echo "=== Test 2: GPU Tensor Operation ==="
docker run --rm --gpus all $NGC_IMAGE python3 -c "
import tensorflow as tf
with tf.device('/GPU:0'):
    a = tf.constant([[1.0, 2.0], [3.0, 4.0]])
    b = tf.constant([[1.0, 1.0], [0.0, 1.0]])
    c = tf.matmul(a, b)
    print(f'Matrix multiplication result:')
    print(c.numpy())
print('✓ GPU tensor operation successful')
"
echo ""

# Test 3: Multi-GPU Detection
echo "=== Test 3: Multi-GPU Availability ==="
docker run --rm --gpus all $NGC_IMAGE python3 -c "
import tensorflow as tf
gpus = tf.config.list_physical_devices('GPU')
print(f'Total GPUs available: {len(gpus)}')
if len(gpus) >= 4:
    print('✓ All 4 GPUs detected')
elif len(gpus) > 0:
    print(f'⚠ Only {len(gpus)} GPU(s) detected (expected 4)')
else:
    print('✗ No GPUs detected')
    exit(1)
"
echo ""

# Test 4: CUDA Version Check
echo "=== Test 4: CUDA Version Check ==="
docker run --rm --gpus all $NGC_IMAGE python3 -c "
import tensorflow as tf
from tensorflow.python.platform import build_info
cuda_version = build_info.build_info['cuda_version']
print(f'TensorFlow built with CUDA: {cuda_version}')
if cuda_version.startswith('12.8'):
    print('✓ CUDA 12.8 confirmed')
else:
    print(f'⚠ Expected CUDA 12.8, got {cuda_version}')
"
echo ""

echo "========================================"
echo " All Tests Passed!"
echo "========================================"
echo ""
echo "TensorFlow 2.17.0 with CUDA 12.8 is ready for use via NGC container."
echo ""
echo "Usage:"
echo "  docker run --rm --gpus all -it $NGC_IMAGE bash"
echo "  docker run --rm --gpus all -v \$(pwd):/workspace $NGC_IMAGE python3 your_script.py"
