# Multi-GPU Framework Compatibility Research
**Epic 1A Technical Research**
**Date:** 2025-10-29
**Status:** ⚠️ ACTIVE ISSUES WITH NCCL P2P AND vLLM

## Executive Summary

Multi-GPU configurations with 4× RTX 5090 cards face **active compatibility challenges** with tensor parallelism and NCCL P2P communication. PyTorch DistributedDataParallel (DDP) is more stable than vLLM tensor parallelism.

### 🚨 Critical Findings

1. **vLLM tensor parallelism:** ⚠️ Known issues with RTX 5090 multi-GPU (active bugs as of March 2025)
2. **NCCL P2P:** ⚠️ Peer-to-peer communication issues between dual RTX 5090 GPUs
3. **PyTorch DDP:** ✅ Generally stable with proper configuration
4. **TensorFlow multi-GPU:** ✅ Compatible but requires CUDA 12.3 (limits RTX 5090 optimization)
5. **CUDA 12.8 requirement:** Mandatory for Blackwell architecture support

---

## PyTorch DistributedDataParallel (DDP)

### Compatibility Status
**Status:** ✅ SUPPORTED with RTX 5090
**CUDA Version:** 12.8 required
**PyTorch Version:** 2.7.0+ required
**Container:** `nvcr.io/nvidia/pytorch:25.02-py3`

### Architecture Overview

```python
# DDP workflow for 4 GPUs
import torch
import torch.distributed as dist
from torch.nn.parallel import DistributedDataParallel as DDP

# 1. Initialize process group
dist.init_process_group(backend='nccl', world_size=4)

# 2. Model distributed across GPUs
model = YourModel().cuda(local_rank)
model = DDP(model, device_ids=[local_rank])

# 3. Data distributed across GPUs (non-overlapping)
sampler = torch.utils.data.distributed.DistributedSampler(dataset)
dataloader = DataLoader(dataset, sampler=sampler)

# 4. Training loop
for data, target in dataloader:
    output = model(data)
    loss = criterion(output, target)
    loss.backward()  # Gradients automatically averaged across GPUs
    optimizer.step()
```

### Core DDP Workflow
1. **Model Replication:** DDP automatically copies model to K GPUs
2. **Data Splitting:** Dataloader splits into K non-overlapping groups
3. **Gradient Synchronization:** Gradients gathered and averaged across GPUs
4. **Model Synchronization:** Updated model synchronized across all processes

---

### Best Practices for 4× RTX 5090

#### 1. Process Group Configuration
```python
import os
import torch.distributed as dist

# NCCL backend recommended for GPU communication
os.environ['MASTER_ADDR'] = 'localhost'
os.environ['MASTER_PORT'] = '12355'
os.environ['WORLD_SIZE'] = '4'  # 4 GPUs
os.environ['RANK'] = str(local_rank)

# Initialize with NCCL
dist.init_process_group(
    backend='nccl',
    init_method='env://',
    world_size=4,
    rank=local_rank
)
```

#### 2. Mixed Precision Training (FP16/FP32)
```python
from torch.cuda.amp import autocast, GradScaler

# RTX 5090 supports both FP32 and FP16
scaler = GradScaler()

for data, target in dataloader:
    with autocast():  # Automatic mixed precision
        output = model(data)
        loss = criterion(output, target)

    scaler.scale(loss).backward()
    scaler.step(optimizer)
    scaler.update()
```

**Performance Gain:** 2-3× training speedup with minimal accuracy loss

#### 3. Memory Management
```python
# Release GPU cache between epochs
import torch

# Delete unused tensors
del intermediate_outputs
torch.cuda.empty_cache()

# Monitor memory usage
print(f"Allocated: {torch.cuda.memory_allocated() / 1e9:.2f} GB")
print(f"Reserved: {torch.cuda.memory_reserved() / 1e9:.2f} GB")
```

**RTX 5090 Memory:** 32GB GDDR7 per GPU = 128GB total

#### 4. Launch Script
```bash
#!/bin/bash
# launch_ddp.sh

# Launch 4 processes (one per GPU)
python -m torch.distributed.launch \
    --nproc_per_node=4 \
    --nnodes=1 \
    --node_rank=0 \
    --master_addr=localhost \
    --master_port=12355 \
    train.py
```

**Alternative (torchrun):**
```bash
torchrun --nproc_per_node=4 train.py
```

---

### NCCL Configuration

#### Environment Variables
```bash
# NCCL optimization for RTX 5090
export NCCL_DEBUG=INFO  # Enable debug logging
export NCCL_IB_DISABLE=1  # Disable InfiniBand (not applicable)
export NCCL_SOCKET_IFNAME=eth0  # Network interface
export NCCL_P2P_LEVEL=NVL  # NVLink level (if available)

# Performance tuning
export NCCL_BUFFSIZE=2097152  # 2MB buffer
export NCCL_NTHREADS=4  # NCCL threads
```

#### Verification
```python
# Check NCCL backend
import torch
print(torch.distributed.is_nccl_available())  # Should be True

# Verify P2P communication
for i in range(4):
    for j in range(4):
        if i != j:
            can_access = torch.cuda.can_device_access_peer(i, j)
            print(f"GPU {i} -> GPU {j}: {can_access}")
```

---

### Known Issues with RTX 5090

#### Issue 1: NCCL Version Compatibility
**Symptom:** Slow multi-GPU training or communication errors
**Cause:** Older NCCL version
**Solution:** Use NCCL 2.18+ (bundled with PyTorch 2.7+)

```bash
# Check NCCL version
python -c "import torch; print(torch.cuda.nccl.version())"
# Should be (2, 18, x) or newer
```

#### Issue 2: PCIe Bandwidth Bottleneck
**Symptom:** Slower than expected multi-GPU scaling
**Cause:** GPUs not connected via NVLink
**Solution:** Ensure motherboard provides x16 PCIe lanes to each GPU

```python
# Check PCIe bandwidth
import subprocess
output = subprocess.check_output(['nvidia-smi', 'topo', '-m'])
print(output.decode())
# Should show PCIe Gen4 x16 for each GPU
```

---

## TensorFlow Multi-GPU Strategy

### Compatibility Status
**Status:** ⚠️ LIMITED (CUDA 12.3 required, not 12.8)
**TensorFlow Version:** 2.16.1
**Strategy:** `tf.distribute.MirroredStrategy`

### Basic Configuration
```python
import tensorflow as tf

# Automatically detect all GPUs
strategy = tf.distribute.MirroredStrategy()

print(f"Number of devices: {strategy.num_replicas_in_sync}")
# Should output: 4

# Create model within strategy scope
with strategy.scope():
    model = create_model()
    model.compile(optimizer='adam', loss='sparse_categorical_crossentropy')

# Train with distributed dataset
dataset = ...
model.fit(dataset, epochs=10)
```

### Limitations with RTX 5090
- **CUDA 12.3:** Official TensorFlow support (not CUDA 12.8)
- **Blackwell Optimization:** Missing latest GPU optimizations
- **Recommendation:** Use PyTorch DDP instead for RTX 5090

---

## vLLM Tensor Parallelism

### Compatibility Status
**Status:** ❌ ACTIVE ISSUES (as of March 2025)
**CUDA Version:** 12.8 required
**Container:** `nvcr.io/nvidia/pytorch:25.02-py3`

### Known Issues

#### Issue 1: Multi-GPU Tensor Parallelism Failure
**GitHub Issue:** vllm-project/vllm #14628
**Symptom:**
```
RuntimeError: NCCL P2P communication failed
Error using two RTX 5090s with TP=2
```

**Single GPU:** ✅ Works
**Multi-GPU (TP=2):** ❌ Fails

**Workaround Attempted:**
```bash
export NCCL_P2P_DISABLE=1  # Does NOT fix the issue
```

**Status:** Active bug, community investigating (as of March 2025)

---

#### Issue 2: NCCL P2P Communication
**GitHub Issue:** NVIDIA/nccl #1637
**Symptom:** NCCL peer-to-peer communication fails with dual RTX 5090

**Affected Frameworks:**
- vLLM (tensor parallelism)
- TensorRT-LLM (multi-GPU inference)

**Root Cause:** NCCL P2P support for Blackwell architecture still maturing

---

### vLLM Setup (Single GPU - WORKING)
```bash
# Pull NGC PyTorch container with CUDA 12.8
docker run --gpus all --ipc=host --ulimit memlock=-1 --ulimit stack=67108864 \
  -it nvcr.io/nvidia/pytorch:25.02-py3

# Install vLLM
pip install vllm

# Environment variable for Flash Attention
export VLLM_FLASH_ATTN_VERSION=2  # Flash Attention 3 not yet compatible

# Run inference (single GPU)
python -m vllm.entrypoints.openai.api_server \
  --model meta-llama/Llama-3-70b \
  --tensor-parallel-size 1  # Single GPU works
```

---

### vLLM Multi-GPU (⚠️ PROBLEMATIC)
```bash
# Attempt multi-GPU tensor parallelism
python -m vllm.entrypoints.openai.api_server \
  --model meta-llama/Llama-3-70b \
  --tensor-parallel-size 4  # 4 GPUs

# Result: NCCL P2P errors reported in community
```

**Recommendation:** Wait for vLLM bug fix before multi-GPU tensor parallelism

---

### Distributed Serving Alternative
```bash
# Use pipeline parallelism instead of tensor parallelism
python -m vllm.entrypoints.openai.api_server \
  --model meta-llama/Llama-3-70b \
  --pipeline-parallel-size 4  # Alternative to TP

# Or use data parallelism (multiple instances)
```

**Trade-off:**
- ✅ Avoids NCCL P2P issues
- ⚠️ Higher memory usage per GPU
- ⚠️ Models must fit in single GPU VRAM

---

## NCCL P2P Troubleshooting

### Diagnostic Commands
```bash
# Check P2P access between GPUs
nvidia-smi topo -m

# Expected output for 4× RTX 5090 on Threadripper PRO:
#       GPU0  GPU1  GPU2  GPU3
# GPU0   X    SYS   SYS   SYS
# GPU1  SYS    X    SYS   SYS
# GPU2  SYS   SYS    X    SYS
# GPU3  SYS   SYS   SYS    X

# Legend:
# X   = Self
# SYS = Connection through PCIe host bridge (no NVLink)
```

### NCCL Tests
```bash
# Install NCCL tests
git clone https://github.com/NVIDIA/nccl-tests.git
cd nccl-tests
make

# Run all-reduce test
./build/all_reduce_perf -b 8 -e 256M -f 2 -g 4

# Check logs for:
# - Bandwidth (should be ~60-80 GB/s per GPU for PCIe Gen4 x16)
# - Latency
# - P2P communication status
```

---

## Performance Benchmarking

### Expected Multi-GPU Scaling (DDP)

| GPUs | Ideal Speedup | Realistic Speedup | Efficiency |
|------|---------------|-------------------|------------|
| 1    | 1×            | 1×                | 100%       |
| 2    | 2×            | 1.8-1.9×          | 90-95%     |
| 4    | 4×            | 3.4-3.6×          | 85-90%     |

**Efficiency Loss Factors:**
- Communication overhead (NCCL)
- Gradient synchronization
- Memory bandwidth contention
- PCIe bandwidth (no NVLink between RTX 5090s)

---

### Bandwidth Limitations

**RTX 5090 Specs:**
- **VRAM Bandwidth:** 1,792 GB/s (GDDR7)
- **PCIe 5.0 x16:** 128 GB/s theoretical (64 GB/s bidirectional)
- **PCIe 4.0 x16:** 64 GB/s theoretical (32 GB/s bidirectional - RECOMMENDED)

**Implication:** GPU-to-GPU communication limited by PCIe, not VRAM

---

## Recommendations for Epic 1A

### Multi-GPU Framework Priority

1. **Primary:** PyTorch DistributedDataParallel (DDP)
   - ✅ Proven stability with RTX 5090
   - ✅ CUDA 12.8 support
   - ✅ Excellent scaling to 4 GPUs
   - ✅ Mixed precision support

2. **Secondary:** TensorFlow MirroredStrategy
   - ⚠️ CUDA 12.3 limitation
   - ⚠️ Missing Blackwell optimizations
   - ✅ Stable multi-GPU support

3. **Avoid (for now):** vLLM Tensor Parallelism
   - ❌ Active NCCL P2P bugs
   - ❌ Multi-GPU failures reported
   - ⚠️ Wait for bug fixes (track GitHub issues)

---

### Configuration Checklist

#### Before Multi-GPU Training:
```bash
# 1. Verify all GPUs detected
nvidia-smi -L
# Should list 4× NVIDIA GeForce RTX 5090

# 2. Check CUDA version
nvcc --version  # Should be 12.8

# 3. Verify PyTorch + CUDA
python -c "import torch; print(torch.__version__); print(torch.version.cuda)"
# Should be PyTorch 2.7+ with CUDA 12.8

# 4. Test NCCL
python -c "import torch; print(torch.distributed.is_nccl_available())"
# Should be True

# 5. Check P2P access
python -c "import torch; print(torch.cuda.can_device_access_peer(0, 1))"
# Check all GPU pairs

# 6. Monitor GPU topology
nvidia-smi topo -m
```

---

### Monitoring During Training

```python
# training_monitor.py
import torch
import time

def monitor_gpus():
    print(f"Time: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    for i in range(torch.cuda.device_count()):
        print(f"GPU {i}:")
        print(f"  Memory Allocated: {torch.cuda.memory_allocated(i)/1e9:.2f} GB")
        print(f"  Memory Reserved: {torch.cuda.memory_reserved(i)/1e9:.2f} GB")
        print(f"  Utilization: {torch.cuda.utilization(i)}%")
    print("-" * 50)

# Call periodically during training
monitor_gpus()
```

---

## Risk Assessment

### 🔴 HIGH RISK
- **vLLM tensor parallelism** - Active bugs with RTX 5090 multi-GPU
- **NCCL P2P** - Communication issues between dual RTX 5090s
- **TensorRT-LLM multi-GPU** - Similar NCCL P2P issues

### 🟡 MEDIUM RISK
- **PCIe bandwidth** - Bottleneck without NVLink (RTX 5090 consumer cards lack NVLink)
- **Scaling efficiency** - 85-90% efficiency expected (not 100%)

### 🟢 LOW RISK
- **PyTorch DDP** - Mature, well-tested framework
- **Single GPU inference** - All frameworks work (vLLM, PyTorch, TF)
- **Data parallelism** - Stable alternative to tensor parallelism

---

## Mitigation Strategies

### For vLLM Multi-GPU Issues:
1. **Use single GPU per model instance** (data parallelism via load balancer)
2. **Monitor vLLM GitHub issues** for bug fixes
3. **Test with NCCL P2P disabled** (may reduce performance)
4. **Consider pipeline parallelism** instead of tensor parallelism

### For NCCL P2P Issues:
1. **Update to latest NCCL** (via PyTorch 2.7+ NGC container)
2. **Verify PCIe topology** with `nvidia-smi topo -m`
3. **Ensure BIOS PCIe settings** (Gen 4.0 mode)
4. **Check NCCL logs** with `NCCL_DEBUG=INFO`

---

## References

- vLLM GitHub Issues: #14452, #14628
- NVIDIA NCCL GitHub: Issue #1637
- PyTorch Distributed Documentation
- NVIDIA NGC Container Release Notes
- Level1Techs RTX 5090 Linux discussions

---

## Next Steps for Epic 1A

1. ✅ Standardize on PyTorch DDP for multi-GPU training
2. ⚠️ Avoid vLLM tensor parallelism until bugs resolved
3. ✅ Implement NCCL monitoring in training scripts
4. ✅ Create fallback: single-GPU vLLM instances with load balancing
5. ✅ Document PCIe topology verification in deployment runbook
6. ⚠️ Subscribe to vLLM GitHub issues for RTX 5090 P2P fixes
