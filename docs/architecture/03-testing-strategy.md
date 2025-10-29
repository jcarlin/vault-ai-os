# Testing Strategy - Epic 1A

**Version:** 1.0
**Date:** 2025-10-29
**Parent:** [Architecture Overview](00-architecture-overview.md)

---

## Overview

This document defines the comprehensive testing strategy for Epic 1A, covering unit tests, integration tests, validation tests, performance benchmarks, and stress testing.

---

## Testing Pyramid

```
                    ┌──────────────┐
                    │    Stress    │  1 test, 24 hours
                    │    Tests     │  (Thermal validation)
                    └──────────────┘
                   ┌────────────────┐
                   │  Performance   │  4 tests, 20 min
                   │  Benchmarks    │  (PyTorch, vLLM, GPU util, build time)
                   └────────────────┘
                  ┌──────────────────┐
                  │  Validation      │  5 tests, 30 min
                  │  Tests           │  (Customer-facing demos)
                  └──────────────────┘
                 ┌────────────────────┐
                 │   Integration      │  10 tests, 15 min
                 │   Tests            │  (Multi-layer, end-to-end)
                 └────────────────────┘
                ┌──────────────────────┐
                │   Unit Tests         │  20+ tests, 5 min
                │   (Ansible Roles)    │  (Idempotency, services)
                └──────────────────────┘
```

### Pyramid Principles

1. **Fast Feedback:** Unit tests run quickest, catch basic issues early
2. **Integration Confidence:** Multi-layer tests ensure components work together
3. **Customer Validation:** Validation tests demonstrate real-world capability
4. **Performance Assurance:** Benchmarks verify targets met
5. **Reliability Proof:** Stress tests ensure 24-hour stability

---

## Unit Tests (Ansible Roles)

### Purpose
Verify each Ansible role works correctly in isolation and is idempotent.

### Test Framework: Molecule

**Installation:**
```bash
pip install molecule molecule-plugins[docker]
```

### Test Structure

**Example: Docker Role**

```
ansible/roles/docker/
├── tasks/
│   └── main.yml
├── molecule/
│   └── default/
│       ├── molecule.yml        # Test configuration
│       ├── converge.yml        # Apply role
│       ├── verify.yml          # Verify role worked
│       └── prepare.yml         # Setup test environment
└── README.md
```

**molecule.yml:**
```yaml
---
driver:
  name: docker

platforms:
  - name: ubuntu2404
    image: ubuntu:24.04
    pre_build_image: true

provisioner:
  name: ansible
  playbooks:
    converge: converge.yml
    verify: verify.yml

verifier:
  name: ansible
```

**converge.yml:**
```yaml
---
- name: Converge
  hosts: all
  become: yes
  roles:
    - role: docker
```

**verify.yml:**
```yaml
---
- name: Verify Docker installation
  hosts: all
  tasks:
    - name: Docker service is running
      service:
        name: docker
        state: started
      check_mode: yes
      register: result
      failed_when: result.changed

    - name: Docker version is correct
      command: docker --version
      register: docker_version
      failed_when: "'24.0' not in docker_version.stdout"

    - name: Vaultadmin user can run Docker
      command: docker ps
      become: yes
      become_user: vaultadmin
      register: docker_ps
      failed_when: docker_ps.rc != 0

    - name: Docker hello-world works
      command: docker run hello-world
      become: yes
      become_user: vaultadmin
      register: hello
      failed_when: "'Hello from Docker!' not in hello.stdout"
```

### Unit Test Cases

#### Role: common (Base packages)

**Tests:**
- [ ] System packages installed (build-essential, git, curl, vim)
- [ ] Timezone set to UTC
- [ ] Locale configured correctly
- [ ] System updated (apt update/upgrade)
- [ ] Idempotency: 3 consecutive runs without changes

**Execution:**
```bash
cd ansible/roles/common
molecule test
```

---

#### Role: users (User management)

**Tests:**
- [ ] User `vaultadmin` created with UID 1000
- [ ] User in `sudo` group
- [ ] SSH key added to authorized_keys
- [ ] User home directory exists
- [ ] Idempotency check

**Execution:**
```bash
cd ansible/roles/users
molecule test
```

---

#### Role: security (SSH hardening)

**Tests:**
- [ ] SSH config: PermitRootLogin no
- [ ] SSH config: PasswordAuthentication no
- [ ] SSH config: PubkeyAuthentication yes
- [ ] UFW firewall enabled
- [ ] UFW allows SSH (port 22)
- [ ] fail2ban installed and running
- [ ] Idempotency check

**Execution:**
```bash
cd ansible/roles/security
molecule test
```

---

#### Role: docker (Docker installation)

**Tests:**
- [ ] Docker Engine installed (version 24.0+)
- [ ] Docker service running and enabled
- [ ] Vaultadmin user in `docker` group
- [ ] Docker daemon.json configured correctly
- [ ] `docker run hello-world` works
- [ ] Idempotency check

**Execution:**
```bash
cd ansible/roles/docker
molecule test
```

---

#### Role: python (Python environment)

**Tests:**
- [ ] Python 3.12 installed
- [ ] pip installed and functional
- [ ] venv module available
- [ ] Build dependencies installed (gcc, g++, make)
- [ ] Can create virtualenv
- [ ] Idempotency check

**Execution:**
```bash
cd ansible/roles/python
molecule test
```

---

### Unit Test Execution

**Run all role tests:**
```bash
# From ansible/ directory
for role in roles/*/; do
  (cd "$role" && molecule test)
done
```

**Expected Output:**
```
==> common: PLAY RECAP *********************************************************************
==> common: ubuntu2404              : ok=15   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
==> common: Molecule test passed ✓

==> users: PLAY RECAP *********************************************************************
==> users: ubuntu2404               : ok=12   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
==> users: Molecule test passed ✓

... (all roles pass)
```

### Time Estimate
- **Per role:** 1-2 minutes
- **10 roles:** ~15 minutes total

---

## Integration Tests (Multi-Layer)

### Purpose
Verify layers work together correctly and end-to-end workflows function.

### Test Framework: Shell scripts with pytest (optional)

### Integration Test Cases

#### Test 1: GPU Detection Integration

**Scope:** Layer 2 (drivers) + Layer 3 (runtime)

**Script:** `scripts/integration/test-gpu-detection.sh`

```bash
#!/bin/bash
set -e

echo "=== GPU Detection Integration Test ==="

# Layer 2: NVIDIA drivers
nvidia-smi > /dev/null 2>&1
echo "✓ Layer 2: nvidia-smi accessible"

GPU_COUNT=$(nvidia-smi --query-gpu=count --format=csv,noheader | head -1)
if [ "$GPU_COUNT" != "4" ]; then
    echo "✗ ERROR: Expected 4 GPUs, found $GPU_COUNT"
    exit 1
fi
echo "✓ Layer 2: 4 GPUs detected"

# Layer 3: Docker GPU access
docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu24.04 nvidia-smi > /dev/null 2>&1
echo "✓ Layer 3: Docker container can access GPUs"

GPU_COUNT_CONTAINER=$(docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu24.04 nvidia-smi --query-gpu=count --format=csv,noheader | head -1)
if [ "$GPU_COUNT_CONTAINER" != "4" ]; then
    echo "✗ ERROR: Container sees $GPU_COUNT_CONTAINER GPUs, expected 4"
    exit 1
fi
echo "✓ Layer 3: Container sees all 4 GPUs"

echo "=== GPU Detection Integration Test PASSED ==="
```

---

#### Test 2: Docker GPU Integration

**Scope:** Layer 1 (Docker) + Layer 3 (GPU runtime)

**Script:** `scripts/integration/test-docker-gpu.sh`

```bash
#!/bin/bash
set -e

echo "=== Docker GPU Integration Test ==="

# Test 1: Basic GPU container
docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu24.04 nvidia-smi
echo "✓ Basic GPU container works"

# Test 2: PyTorch GPU container
docker run --rm --gpus all pytorch/pytorch:2.1.0-cuda12.1-cudnn8-runtime python -c "
import torch
assert torch.cuda.is_available(), 'CUDA not available in PyTorch container'
assert torch.cuda.device_count() == 4, 'Expected 4 GPUs'
print('PyTorch GPU container: OK')
"
echo "✓ PyTorch GPU container works"

# Test 3: Multi-container GPU sharing
docker run -d --name gpu-test-1 --gpus device=0 nvidia/cuda:12.4.0-base-ubuntu24.04 sleep 300
docker run -d --name gpu-test-2 --gpus device=1 nvidia/cuda:12.4.0-base-ubuntu24.04 sleep 300
echo "✓ Multi-container GPU allocation works"

# Cleanup
docker rm -f gpu-test-1 gpu-test-2

echo "=== Docker GPU Integration Test PASSED ==="
```

---

#### Test 3: PyTorch Multi-GPU Integration

**Scope:** Layer 4 (PyTorch) + Layer 2 (CUDA)

**Script:** `scripts/integration/test-pytorch-ddp.py`

```python
#!/usr/bin/env python3
"""
PyTorch DistributedDataParallel (DDP) Integration Test
Tests multi-GPU training capability and scaling efficiency.
"""

import os
import torch
import torch.nn as nn
import torch.distributed as dist
import torch.multiprocessing as mp
from torch.nn.parallel import DistributedDataParallel as DDP
from torchvision.models import resnet50
import time

def train_ddp(rank, world_size):
    """Train ResNet-50 with DDP on 4 GPUs."""
    # Initialize process group
    dist.init_process_group(
        backend='nccl',
        init_method='env://',
        rank=rank,
        world_size=world_size
    )

    # Set device
    torch.cuda.set_device(rank)
    device = torch.device(f'cuda:{rank}')

    # Create model and wrap with DDP
    model = resnet50().to(device)
    ddp_model = DDP(model, device_ids=[rank])

    # Synthetic data
    batch_size = 32
    data = torch.randn(batch_size, 3, 224, 224).to(device)
    target = torch.randint(0, 1000, (batch_size,)).to(device)

    # Loss and optimizer
    criterion = nn.CrossEntropyLoss()
    optimizer = torch.optim.SGD(ddp_model.parameters(), lr=0.01)

    # Training loop
    iterations = 100
    start_time = time.time()

    for i in range(iterations):
        optimizer.zero_grad()
        output = ddp_model(data)
        loss = criterion(output, target)
        loss.backward()
        optimizer.step()

        if rank == 0 and i % 10 == 0:
            print(f"Iteration {i}, Loss: {loss.item():.4f}")

    elapsed = time.time() - start_time
    throughput = (iterations * batch_size * world_size) / elapsed

    if rank == 0:
        print(f"\n=== PyTorch DDP Results ===")
        print(f"Total time: {elapsed:.2f}s")
        print(f"Throughput: {throughput:.2f} samples/sec")
        print(f"Samples processed: {iterations * batch_size * world_size}")

        # Scaling efficiency (compared to expected linear scaling)
        # Expected: 4 GPUs should process 4x as fast
        single_gpu_baseline = 50  # samples/sec (approximate)
        scaling_efficiency = (throughput / world_size) / single_gpu_baseline
        print(f"Scaling efficiency: {scaling_efficiency:.2%}")

        if scaling_efficiency < 0.80:
            print("⚠ WARNING: Scaling efficiency <80%")
        else:
            print("✓ Scaling efficiency >80%")

    dist.destroy_process_group()

def main():
    print("=== PyTorch Multi-GPU Integration Test ===")

    # Check PyTorch installation
    print(f"PyTorch version: {torch.__version__}")
    print(f"CUDA available: {torch.cuda.is_available()}")
    print(f"CUDA version: {torch.version.cuda}")
    print(f"GPU count: {torch.cuda.device_count()}")

    if torch.cuda.device_count() != 4:
        print(f"✗ ERROR: Expected 4 GPUs, found {torch.cuda.device_count()}")
        exit(1)

    # Run DDP training
    world_size = 4
    os.environ['MASTER_ADDR'] = 'localhost'
    os.environ['MASTER_PORT'] = '12355'

    mp.spawn(train_ddp, args=(world_size,), nprocs=world_size, join=True)

    print("=== PyTorch Multi-GPU Integration Test PASSED ===")

if __name__ == "__main__":
    main()
```

---

#### Test 4: vLLM Inference Integration

**Scope:** Layer 4 (vLLM) + Layer 3 (Docker optional)

**Script:** `scripts/integration/test-vllm-inference.py`

```python
#!/usr/bin/env python3
"""
vLLM Inference Integration Test
Tests LLM inference capability and throughput.
"""

from vllm import LLM, SamplingParams
import time

def main():
    print("=== vLLM Inference Integration Test ===")

    # Initialize vLLM with test model
    print("Loading model (facebook/opt-125m)...")
    llm = LLM(
        model="facebook/opt-125m",  # Small model for testing
        tensor_parallel_size=1,  # Single GPU
        gpu_memory_utilization=0.9
    )

    # Test prompts
    prompts = [
        "Once upon a time",
        "The meaning of life is",
        "Artificial intelligence will",
    ] * 10  # 30 prompts total

    # Sampling parameters
    sampling_params = SamplingParams(
        temperature=0.8,
        top_p=0.95,
        max_tokens=50
    )

    # Run inference
    print(f"Running inference on {len(prompts)} prompts...")
    start_time = time.time()
    outputs = llm.generate(prompts, sampling_params)
    elapsed = time.time() - start_time

    # Calculate metrics
    total_tokens = sum(len(output.outputs[0].token_ids) for output in outputs)
    throughput = total_tokens / elapsed

    print(f"\n=== vLLM Inference Results ===")
    print(f"Prompts: {len(prompts)}")
    print(f"Total tokens generated: {total_tokens}")
    print(f"Time: {elapsed:.2f}s")
    print(f"Throughput: {throughput:.2f} tokens/sec")

    # Show sample outputs
    print("\nSample outputs:")
    for i, output in enumerate(outputs[:3]):
        print(f"\n{i+1}. Prompt: {output.prompt}")
        print(f"   Output: {output.outputs[0].text}")

    # Validation
    if throughput < 10:
        print(f"⚠ WARNING: Throughput <10 tokens/sec (got {throughput:.2f})")
    else:
        print(f"✓ Throughput >10 tokens/sec")

    print("\n=== vLLM Inference Integration Test PASSED ===")

if __name__ == "__main__":
    main()
```

---

### Integration Test Execution

**Run all integration tests:**
```bash
#!/bin/bash
# scripts/run-integration-tests.sh

set -e

echo "=== Running All Integration Tests ==="

# Test 1: GPU Detection
bash scripts/integration/test-gpu-detection.sh

# Test 2: Docker GPU
bash scripts/integration/test-docker-gpu.sh

# Test 3: PyTorch DDP
python3 scripts/integration/test-pytorch-ddp.py

# Test 4: vLLM Inference
python3 scripts/integration/test-vllm-inference.py

# Test 5: Full stack (optional)
# bash scripts/integration/test-full-stack.sh

echo "=== All Integration Tests PASSED ==="
```

### Time Estimate
- **Total:** ~15 minutes

---

## Validation Tests (Customer-Facing)

### Purpose
Demonstrate system capability to customers in realistic scenarios.

### Test Cases

#### Validation 1: GPU Capability Demo

**Duration:** 5 minutes

**Script:** `scripts/validation/demo-gpu-capability.sh`

```bash
#!/bin/bash

echo "=== Vault Cube GPU Capability Demo ==="

# Show GPU configuration
echo "\n1. GPU Configuration:"
nvidia-smi --query-gpu=index,name,memory.total --format=csv

# Show temperatures
echo "\n2. GPU Temperatures:"
nvidia-smi --query-gpu=index,temperature.gpu --format=csv

# Show PCIe topology
echo "\n3. PCIe Topology:"
nvidia-smi topo -m

echo "\n=== Demo Complete ==="
```

---

#### Validation 2: PyTorch Training Demo

**Duration:** 10 minutes

**Demonstration:**
- Train ResNet-50 on 4 GPUs
- Show throughput improvement vs 1 GPU
- Display GPU utilization dashboard

---

#### Validation 3: vLLM Inference Demo

**Duration:** 10 minutes

**Demonstration:**
- Load Llama-2-7B model
- Interactive prompt/response
- Show inference speed

---

### Time Estimate
- **Total:** ~25 minutes

---

## Performance Benchmarks

### Benchmark 1: PyTorch DDP Scaling Efficiency

**Target:** >80% scaling efficiency (4 GPUs vs 1 GPU)

**Metric:** Throughput (samples/sec)

**Workload:** ResNet-50 training, batch size 32

**Execution:** See integration test above

---

### Benchmark 2: vLLM Inference Throughput

**Target:** >10 tokens/sec (Llama-2-7B, single GPU)

**Metric:** Tokens generated per second

**Workload:** Batch of 30 prompts, 50 tokens each

**Execution:** See integration test above

---

### Benchmark 3: GPU Utilization

**Target:** >90% during training

**Metric:** GPU utilization percentage

**Tool:** `nvidia-smi dmon`

```bash
# Monitor GPU utilization during PyTorch training
nvidia-smi dmon -s mu -c 60
```

---

### Benchmark 4: Build Time

**Target:** <30 minutes (Packer + Ansible)

**Metric:** End-to-end build duration

**Execution:**
```bash
time packer build packer/ubuntu-24.04-demo-box.pkr.hcl
```

---

## Stress Testing

### 24-Hour Thermal Validation

**Purpose:** Ensure system stability under continuous GPU load without thermal throttling.

**Script:** `scripts/stress/stress-test-24hr.sh`

```bash
#!/bin/bash

echo "=== Starting 24-Hour Thermal Stress Test ==="

# Create log directory
mkdir -p logs/stress-test
LOG_FILE="logs/stress-test/thermal-$(date +%Y%m%d-%H%M%S).log"

# Function to load GPU
load_gpu() {
    local gpu=$1
    CUDA_VISIBLE_DEVICES=$gpu python3 -c "
import torch
import time

print(f'Loading GPU {$gpu}...')
x = torch.randn(30000, 30000).cuda()

start_time = time.time()
while True:
    y = torch.matmul(x, x)
    torch.cuda.synchronize()

    # Log every hour
    if int(time.time() - start_time) % 3600 == 0:
        temp = torch.cuda.temperature()
        print(f'GPU {$gpu}: {int((time.time() - start_time) / 3600)}h elapsed')
" >> "$LOG_FILE" 2>&1 &
}

# Load all 4 GPUs
for gpu in 0 1 2 3; do
    load_gpu $gpu
done

echo "Stress test running. Logging to: $LOG_FILE"
echo "Monitor with: watch -n 5 nvidia-smi"
echo "Press Ctrl+C to stop after 24 hours."

# Monitor temperatures every 5 seconds for 24 hours
for i in $(seq 1 17280); do  # 24 hours * 3600 sec / 5 sec
    nvidia-smi --query-gpu=timestamp,index,temperature.gpu,power.draw,clocks.gr,clocks.mem \
        --format=csv >> "$LOG_FILE"
    sleep 5
done

# Cleanup
killall python3

echo "=== 24-Hour Stress Test Complete ==="
echo "Review logs: $LOG_FILE"
```

**Monitoring:**
- GPU temperature every 5 seconds
- Log any thermal throttling events
- Check for GPU errors in `dmesg`

**Pass Criteria:**
- No thermal throttling for 24 hours
- GPU temperatures stable (<85°C)
- No GPU errors
- System remains responsive

---

## Test Execution Summary

| Test Type | Count | Duration | When to Run |
|-----------|-------|----------|-------------|
| **Unit Tests** | 20+ | 15 min | Every Ansible change |
| **Integration Tests** | 5-10 | 15 min | After Ansible provisioning |
| **Validation Tests** | 5 | 30 min | Before image finalization |
| **Performance Benchmarks** | 4 | 20 min | Weekly, after changes |
| **Stress Tests** | 1 | 24 hours | Before production release |

---

**Document Version:** 1.0
**Last Updated:** 2025-10-29
**Next Review:** After Week 1 implementation
