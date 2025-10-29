# Epic 1a: Demo Box Operation

**Version:** 1.0
**Date:** 2025-10-29
**Status:** Planned
**Duration:** 2-3 weeks
**Effort:** 60-90 hours

---

## Executive Summary

Epic 1a focuses on creating a **functional AI workstation image** that can run PyTorch, TensorFlow, and vLLM workloads on 4× NVIDIA RTX 5090 GPUs. This epic delivers a working demo box for customer validation and internal testing, laying the foundation for production hardening in Epic 1b.

**Key Deliverable:** Bootable golden image that demonstrates full GPU-accelerated AI/ML capability.

---

## Goals

### Primary Goal
Build a functional AI workstation image that enables customer demos and validates the core Vault Cube hardware platform.

### Secondary Goals
1. Validate RTX 5090 driver compatibility with Ubuntu 24.04 LTS
2. Prove 4-GPU parallel compute capability
3. Establish automated image building pipeline (Packer + Ansible)
4. Identify thermal/power constraints early
5. Create foundation for production hardening (Epic 1b)

---

## Scope

### In Scope
- Ubuntu 24.04 LTS base installation
- NVIDIA drivers + CUDA 12.4+ toolkit
- Docker runtime with GPU access
- PyTorch 2.x with CUDA support
- TensorFlow 2.x with CUDA support
- vLLM for LLM inference
- Multi-GPU validation (4× RTX 5090)
- Basic security hardening (SSH, firewall)
- 24-hour thermal stress testing
- Demo box setup documentation

### Out of Scope (Deferred to Epic 1b)
- Full CIS Level 1 compliance (only basic hardening)
- Full disk encryption (LUKS)
- Air-gap deployment support
- Enterprise monitoring (Prometheus/Grafana)
- MLPerf benchmarks
- 72-hour soak testing
- Production deployment documentation
- Compliance certifications

---

## Timeline

### Week 1: Foundation (MacBook-Friendly)
**Duration:** 5 days
**Effort:** 24-33 hours
**Key Milestone:** Base Ubuntu image builds automatically

```
Mon-Tue:  Development environment + Git repository setup
Wed-Thu:  Packer template development
Fri:      Ansible base system configuration begins
```

### Week 2: AI Runtime (GPU Hardware Required)
**Duration:** 5 days
**Effort:** 22-32 hours
**Key Milestone:** All AI frameworks installed, GPUs accessible
**Hardware Blocker:** 4× RTX 5090 GPUs must be available by Monday

```
Mon:      NVIDIA driver installation begins
Tue:      CUDA validation + Docker GPU access
Wed:      PyTorch installation and testing
Thu:      TensorFlow + vLLM installation
Fri:      Multi-GPU validation begins
```

### Week 3: Validation & Documentation
**Duration:** 5 days
**Effort:** 14-25 hours
**Key Milestone:** Demo box operational, documentation complete

```
Mon-Tue:  Multi-GPU testing (PyTorch DDP, vLLM inference)
Wed:      24-hour stress test initiated
Thu:      Stress test monitoring + issue resolution
Fri:      Documentation + handoff preparation
```

### Week 4: Buffer (Optional)
**Duration:** 0-5 days
**Effort:** Variable
**Purpose:** Contingency for unexpected issues, driver debugging, thermal problems

---

## Detailed Task Breakdown

### Phase 1: Foundation (Week 1)

#### Task 1a.1: Development Environment Setup
**Effort:** 2-3 hours
**MacBook:** ✅ Yes
**Dependencies:** None

**Description:**
Set up local development environment for Packer and Ansible development.

**Actions:**
- Install VirtualBox or UTM (Apple Silicon) for VM testing
- Install Packer 1.9+
- Install Ansible 2.15+
- Configure VM with 8GB RAM, 4 cores minimum for testing
- Validate Packer and Ansible versions

**Acceptance Criteria:**
- [ ] Packer version ≥ 1.9 installed
- [ ] Ansible version ≥ 2.15 installed
- [ ] VM hypervisor functional
- [ ] Test VM can boot Ubuntu 24.04 ISO

---

#### Task 1a.2: Git Repository Structure
**Effort:** 1 hour
**MacBook:** ✅ Yes
**Dependencies:** None

**Description:**
Initialize Git repository with proper structure for Packer and Ansible code.

**Actions:**
```bash
git init
git branch -M main

# Create directory structure
mkdir -p {packer,ansible/{playbooks,roles,inventory},scripts,tests,docs}
touch .gitignore README.md

# .gitignore entries
echo "*.box" >> .gitignore
echo "*.qcow2" >> .gitignore
echo "*.img" >> .gitignore
echo ".packer_cache/" >> .gitignore
echo "packer_cache/" >> .gitignore
echo "*.retry" >> .gitignore
echo ".vagrant/" >> .gitignore

git add .
git commit -m "Initial repository structure"
```

**Acceptance Criteria:**
- [ ] Git repository initialized
- [ ] Directory structure created
- [ ] .gitignore configured for Packer/Ansible artifacts
- [ ] Initial commit completed

---

#### Task 1a.3: Packer Template Creation
**Effort:** 6-10 hours
**MacBook:** ✅ Yes
**Dependencies:** Task 1a.1, 1a.2

**Description:**
Create Packer template for automated Ubuntu 24.04 LTS installation.

**Actions:**
- Create `packer/ubuntu-24.04-demo-box.pkr.hcl`
- Configure Ubuntu 24.04 LTS autoinstall (cloud-init)
- Set up SSH access for Ansible provisioning
- Configure initial user account
- Test minimal build (Ubuntu only, no Ansible provisioning yet)

**Technical Details:**
```hcl
source "qemu" "ubuntu-2404" {
  iso_url          = "https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso"
  iso_checksum     = "sha256:..."
  memory           = 8192
  cpus             = 4
  disk_size        = "50G"
  format           = "qcow2"
  accelerator      = "kvm" # or "hvf" for macOS
  ssh_username     = "vaultadmin"
  ssh_password     = "temp-password"
  ssh_timeout      = "20m"
  shutdown_command = "echo 'vaultadmin' | sudo -S shutdown -P now"
}

build {
  sources = ["source.qemu.ubuntu-2404"]

  provisioner "ansible" {
    playbook_file = "../ansible/playbooks/site.yml"
  }
}
```

**Acceptance Criteria:**
- [ ] Packer template builds Ubuntu 24.04 image successfully
- [ ] Build completes in <30 minutes
- [ ] SSH access to built image works
- [ ] Image boots successfully in VM

---

#### Task 1a.4: Ansible Playbook - Base System Configuration
**Effort:** 6-8 hours
**MacBook:** ✅ Yes
**Dependencies:** Task 1a.3

**Description:**
Create Ansible playbook for base system configuration (users, packages, networking).

**Actions:**
- Create `ansible/playbooks/site.yml` master playbook
- Create roles:
  - `common` - System updates, timezone, hostname
  - `users` - Non-root user creation, sudo configuration
  - `packages` - Essential packages (build-essential, git, curl, vim, etc.)
  - `networking` - Network configuration, DNS
- Configure system-wide settings
- Test playbook idempotency (run 3× times, no errors)

**Key Packages:**
```yaml
packages:
  - build-essential
  - git
  - curl
  - wget
  - vim
  - htop
  - iotop
  - net-tools
  - openssh-server
  - ca-certificates
  - gnupg
  - lsb-release
```

**Acceptance Criteria:**
- [ ] Base system playbook executes successfully
- [ ] Playbook is idempotent (3 consecutive runs without errors)
- [ ] Non-root user `vaultadmin` created with sudo access
- [ ] System timezone set to UTC
- [ ] Essential packages installed

---

#### Task 1a.5: Ansible Playbook - Basic Security
**Effort:** 4-6 hours
**MacBook:** ✅ Yes
**Dependencies:** Task 1a.4

**Description:**
Implement basic security hardening (SSH key-only auth, firewall, fail2ban).

**Actions:**
- Create `ansible/roles/security` role
- Configure SSH:
  - Disable password authentication
  - Disable root login
  - Change SSH port (optional: 2222)
  - Configure key-based authentication only
- Install and configure UFW firewall:
  - Default deny incoming
  - Allow SSH (port 22 or 2222)
  - Allow HTTP/HTTPS (for Grafana in future)
- Install fail2ban for SSH brute-force protection
- Configure automatic security updates

**SSH Hardening:**
```yaml
# /etc/ssh/sshd_config
PermitRootLogin: no
PasswordAuthentication: no
PubkeyAuthentication: yes
Port: 22
AllowUsers: vaultadmin
```

**Acceptance Criteria:**
- [ ] SSH key-based authentication required (passwords disabled)
- [ ] Root login disabled
- [ ] UFW firewall enabled and configured
- [ ] fail2ban installed and monitoring SSH
- [ ] Automatic security updates enabled

---

#### Task 1a.6: Ansible Playbook - Docker Installation
**Effort:** 3-4 hours
**MacBook:** ✅ Yes
**Dependencies:** Task 1a.4

**Description:**
Install Docker Engine and containerd for GPU container support.

**Actions:**
- Create `ansible/roles/docker` role
- Add Docker official APT repository
- Install Docker Engine (not Docker Desktop - licensing)
- Install containerd
- Configure vaultadmin user in `docker` group
- Configure Docker daemon settings:
  - Use systemd cgroup driver
  - Enable live restore
  - Set storage driver (overlay2)
- Test Docker installation with `hello-world` container

**Docker Daemon Config:**
```json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "live-restore": true
}
```

**Acceptance Criteria:**
- [ ] Docker Engine installed (version 24.x+)
- [ ] containerd runtime operational
- [ ] vaultadmin user can run `docker ps` without sudo
- [ ] `docker run hello-world` executes successfully
- [ ] Docker service starts on boot

---

#### Task 1a.7: Ansible Playbook - Python Environment
**Effort:** 2-3 hours
**MacBook:** ✅ Yes
**Dependencies:** Task 1a.4

**Description:**
Install Python 3.10+ and pip for ML framework installation.

**Actions:**
- Create `ansible/roles/python` role
- Install Python 3.10+ (Ubuntu 24.04 includes 3.12 by default)
- Install pip, virtualenv, venv
- Install build dependencies for Python packages
- Configure pip to use local cache (for faster builds)
- Verify Python installation

**Python Packages:**
```yaml
python_packages:
  - python3
  - python3-pip
  - python3-venv
  - python3-dev
  - python-is-python3
```

**Build Dependencies:**
```yaml
build_deps:
  - gcc
  - g++
  - make
  - cmake
  - libssl-dev
  - libffi-dev
```

**Acceptance Criteria:**
- [ ] Python 3.10+ installed (`python --version`)
- [ ] pip installed and functional (`pip --version`)
- [ ] virtualenv and venv modules available
- [ ] Build dependencies installed
- [ ] Test: `python -c "import sys; print(sys.version)"`

---

### Phase 2: AI Runtime (Week 2 - GPU Required)

**BLOCKER:** Tasks 1a.8-1a.12 require 4× RTX 5090 GPUs available.
**Mitigation:** If GPUs delayed, continue with Epic 1b preparation (air-gap setup).

---

#### Task 1a.8: Ansible Playbook - NVIDIA Drivers + CUDA
**Effort:** 8-12 hours
**MacBook:** ❌ No (GPU hardware required)
**Dependencies:** Task 1a.4, GPU hardware

**Description:**
Install NVIDIA drivers and CUDA toolkit for RTX 5090 GPUs.

**Actions:**
- Create `ansible/roles/nvidia` role
- Add NVIDIA CUDA repository
- Install NVIDIA driver 550+ (RTX 5090 support)
- Install CUDA toolkit 12.4+
- Install cuDNN 9.x
- Configure kernel module loading
- Create exceptions for CIS hardening (kernel modules)
- Reboot system
- Validate installation with `nvidia-smi`

**Driver Version Matrix:**
| Component | Version | Notes |
|-----------|---------|-------|
| NVIDIA Driver | 550.127.05+ | RTX 5090 minimum |
| CUDA Toolkit | 12.4.0+ | PyTorch compatibility |
| cuDNN | 9.0.0+ | TensorFlow compatibility |

**Validation Commands:**
```bash
nvidia-smi                          # Should show 4× RTX 5090 GPUs
nvcc --version                      # CUDA compiler version
nvidia-smi -L                       # List all GPUs
nvidia-smi topo -m                  # GPU topology (PCIe layout)
```

**Known Issues:**
- RTX 5090 is new hardware - driver may have bugs
- CIS hardening may block kernel module loading (create exceptions)
- PCIe 5.0 may require BIOS configuration

**Acceptance Criteria:**
- [ ] NVIDIA driver 550+ installed
- [ ] `nvidia-smi` shows all 4× RTX 5090 GPUs
- [ ] CUDA toolkit 12.4+ installed
- [ ] cuDNN 9.x installed
- [ ] GPU memory, temperature, utilization visible in nvidia-smi
- [ ] No GPU errors in `dmesg | grep nvidia`

---

#### Task 1a.9: Ansible Playbook - NVIDIA Container Toolkit
**Effort:** 3-4 hours
**MacBook:** ❌ No (GPU hardware required)
**Dependencies:** Task 1a.6, Task 1a.8

**Description:**
Install NVIDIA Container Toolkit for Docker GPU access.

**Actions:**
- Create `ansible/roles/nvidia-container-toolkit` role
- Add NVIDIA Container Toolkit repository
- Install nvidia-container-toolkit package
- Configure Docker daemon to use nvidia runtime
- Restart Docker service
- Test GPU access from Docker container

**Docker Runtime Config:**
```json
{
  "runtimes": {
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  },
  "default-runtime": "nvidia"
}
```

**Test Command:**
```bash
docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu24.04 nvidia-smi
# Should show 4× RTX 5090 GPUs from within container
```

**Acceptance Criteria:**
- [ ] NVIDIA Container Toolkit installed
- [ ] Docker daemon configured with nvidia runtime
- [ ] Test container can access all 4 GPUs
- [ ] `docker run --gpus all nvidia/cuda:12.4.0-base nvidia-smi` works

---

#### Task 1a.10: Ansible Playbook - PyTorch Installation
**Effort:** 4-6 hours
**MacBook:** ❌ No (GPU hardware required)
**Dependencies:** Task 1a.7, Task 1a.8

**Description:**
Install PyTorch 2.x with CUDA 12.4 support.

**Actions:**
- Create `ansible/roles/pytorch` role
- Determine PyTorch version compatible with CUDA 12.4
- Install PyTorch with pip (CUDA build):
  ```bash
  pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
  ```
- Verify PyTorch can detect GPUs
- Test multi-GPU capability
- Create validation script

**Validation Script:**
```python
import torch

print(f"PyTorch version: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"CUDA version: {torch.version.cuda}")
print(f"GPU count: {torch.cuda.device_count()}")

for i in range(torch.cuda.device_count()):
    print(f"GPU {i}: {torch.cuda.get_device_name(i)}")

# Test tensor on GPU
if torch.cuda.is_available():
    x = torch.randn(1000, 1000).cuda()
    y = torch.randn(1000, 1000).cuda()
    z = torch.matmul(x, y)
    print(f"GPU tensor operation successful: {z.shape}")
```

**Acceptance Criteria:**
- [ ] PyTorch 2.x installed with CUDA 12.4 support
- [ ] `torch.cuda.is_available()` returns `True`
- [ ] `torch.cuda.device_count()` returns `4`
- [ ] All 4 GPUs detected by PyTorch
- [ ] Simple GPU tensor operation succeeds

---

#### Task 1a.11: Ansible Playbook - TensorFlow Installation
**Effort:** 4-6 hours
**MacBook:** ❌ No (GPU hardware required)
**Dependencies:** Task 1a.7, Task 1a.8

**Description:**
Install TensorFlow 2.x with CUDA 12.4 support.

**Actions:**
- Create `ansible/roles/tensorflow` role
- Determine TensorFlow version compatible with CUDA 12.4
- Install TensorFlow with pip (GPU build):
  ```bash
  pip3 install tensorflow[and-cuda]
  ```
- Configure TensorFlow to use all GPUs
- Verify TensorFlow can detect GPUs
- Test multi-GPU capability
- Create validation script

**Validation Script:**
```python
import tensorflow as tf

print(f"TensorFlow version: {tf.__version__}")
print(f"GPU devices: {tf.config.list_physical_devices('GPU')}")
print(f"GPU count: {len(tf.config.list_physical_devices('GPU'))}")

# Test GPU operation
if tf.config.list_physical_devices('GPU'):
    with tf.device('/GPU:0'):
        a = tf.constant([[1.0, 2.0], [3.0, 4.0]])
        b = tf.constant([[1.0, 1.0], [0.0, 1.0]])
        c = tf.matmul(a, b)
        print(f"GPU tensor operation successful: {c}")
```

**Acceptance Criteria:**
- [ ] TensorFlow 2.x installed with CUDA 12.4 support
- [ ] `tf.config.list_physical_devices('GPU')` shows 4 GPUs
- [ ] Simple GPU tensor operation succeeds
- [ ] TensorFlow can allocate memory on all GPUs

---

#### Task 1a.12: Ansible Playbook - vLLM Installation
**Effort:** 3-4 hours
**MacBook:** ❌ No (GPU hardware required)
**Dependencies:** Task 1a.7, Task 1a.8, Task 1a.10

**Description:**
Install vLLM for LLM inference with multi-GPU support.

**Actions:**
- Create `ansible/roles/vllm` role
- Install vLLM with pip:
  ```bash
  pip3 install vllm
  ```
- Verify vLLM installation
- Download small test model (e.g., facebook/opt-125m)
- Test vLLM inference on single GPU
- Create validation script

**Validation Script:**
```python
from vllm import LLM, SamplingParams

# Initialize vLLM with test model
llm = LLM(model="facebook/opt-125m")

# Test inference
prompts = ["Hello, my name is", "The capital of France is"]
sampling_params = SamplingParams(temperature=0.8, top_p=0.95)
outputs = llm.generate(prompts, sampling_params)

for output in outputs:
    print(f"Prompt: {output.prompt}")
    print(f"Generated: {output.outputs[0].text}\n")
```

**Acceptance Criteria:**
- [ ] vLLM installed successfully
- [ ] Test model (opt-125m) downloaded
- [ ] vLLM can initialize and use GPU
- [ ] Inference test produces reasonable output
- [ ] vLLM reports GPU utilization

---

### Phase 3: Validation (Week 3)

#### Task 1a.13: GPU Detection Validation
**Effort:** 4-6 hours
**MacBook:** ❌ No (GPU hardware required)
**Dependencies:** Task 1a.8

**Description:**
Comprehensive GPU detection and health validation.

**Actions:**
- Create validation script: `scripts/validate-gpus.sh`
- Check all 4 GPUs visible in nvidia-smi
- Verify GPU memory (should be ~32GB per RTX 5090)
- Check GPU temperatures (should be <50°C at idle)
- Verify PCIe link speed (should be Gen5 x16)
- Check CUDA version consistency
- Log GPU topology (PCIe layout)
- Test GPU memory allocation/deallocation
- Check for GPU errors in system logs

**Validation Script:**
```bash
#!/bin/bash
set -e

echo "=== GPU Detection Validation ==="

# Check GPU count
GPU_COUNT=$(nvidia-smi --query-gpu=count --format=csv,noheader | head -1)
if [ "$GPU_COUNT" != "4" ]; then
    echo "ERROR: Expected 4 GPUs, found $GPU_COUNT"
    exit 1
fi
echo "✓ GPU Count: $GPU_COUNT"

# Check GPU memory
nvidia-smi --query-gpu=index,name,memory.total --format=csv
echo "✓ GPU Memory detected"

# Check temperatures
MAX_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader | sort -nr | head -1)
echo "✓ Max GPU Temperature: ${MAX_TEMP}°C"
if [ "$MAX_TEMP" -gt 60 ]; then
    echo "WARNING: GPU temperature >60°C at idle"
fi

# Check PCIe link speed
nvidia-smi --query-gpu=index,pcie.link.gen.current,pcie.link.width.current --format=csv
echo "✓ PCIe link speed checked"

# Check CUDA
nvcc --version
echo "✓ CUDA toolkit verified"

# Check for GPU errors
GPU_ERRORS=$(dmesg | grep -i nvidia | grep -i error | wc -l)
if [ "$GPU_ERRORS" -gt 0 ]; then
    echo "WARNING: Found $GPU_ERRORS GPU errors in dmesg"
    dmesg | grep -i nvidia | grep -i error
fi

echo "=== GPU Validation Complete ==="
```

**Acceptance Criteria:**
- [ ] All 4× RTX 5090 GPUs detected
- [ ] GPU memory verified (~32GB each)
- [ ] Idle temperatures <60°C
- [ ] PCIe Gen5 x16 link confirmed
- [ ] No GPU errors in system logs
- [ ] Validation script exits with code 0

---

#### Task 1a.14: PyTorch Multi-GPU Validation
**Effort:** 3-4 hours
**MacBook:** ❌ No (GPU hardware required)
**Dependencies:** Task 1a.10, Task 1a.13

**Description:**
Test PyTorch DistributedDataParallel (DDP) on 4 GPUs.

**Actions:**
- Create PyTorch DDP test script: `scripts/test-pytorch-ddp.py`
- Implement ResNet-50 training on synthetic data
- Configure DDP with NCCL backend
- Run training for 100 iterations
- Measure GPU utilization and scaling efficiency
- Log training throughput (samples/sec)

**Test Script:**
```python
import torch
import torch.nn as nn
import torch.distributed as dist
import torch.multiprocessing as mp
from torch.nn.parallel import DistributedDataParallel as DDP
from torchvision.models import resnet50
import time

def train_ddp(rank, world_size):
    # Initialize process group
    dist.init_process_group(backend='nccl', init_method='env://',
                           rank=rank, world_size=world_size)

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
    start_time = time.time()
    for i in range(100):
        optimizer.zero_grad()
        output = ddp_model(data)
        loss = criterion(output, target)
        loss.backward()
        optimizer.step()

        if rank == 0 and i % 10 == 0:
            print(f"Iteration {i}, Loss: {loss.item():.4f}")

    elapsed = time.time() - start_time
    throughput = (100 * batch_size * world_size) / elapsed

    if rank == 0:
        print(f"\nTraining Complete!")
        print(f"Total time: {elapsed:.2f}s")
        print(f"Throughput: {throughput:.2f} samples/sec")
        print(f"Scaling efficiency: {(throughput / world_size) / (throughput / world_size):.2%}")

    dist.destroy_process_group()

if __name__ == "__main__":
    world_size = 4  # 4 GPUs
    os.environ['MASTER_ADDR'] = 'localhost'
    os.environ['MASTER_PORT'] = '12355'

    mp.spawn(train_ddp, args=(world_size,), nprocs=world_size, join=True)
```

**Success Metrics:**
- **Target Throughput:** >100 samples/sec (4-GPU)
- **Target Scaling Efficiency:** >80% (vs single GPU)
- **Max GPU Utilization:** >90% during training

**Acceptance Criteria:**
- [ ] PyTorch DDP test completes without errors
- [ ] All 4 GPUs utilized during training
- [ ] Scaling efficiency >80%
- [ ] No NCCL errors in logs
- [ ] GPU utilization >90% during training

---

#### Task 1a.15: vLLM Inference Validation
**Effort:** 2-3 hours
**MacBook:** ❌ No (GPU hardware required)
**Dependencies:** Task 1a.12, Task 1a.13

**Description:**
Test vLLM inference performance on Llama-2-7B model.

**Actions:**
- Download Llama-2-7B model (or smaller test model if unavailable)
- Create vLLM inference test: `scripts/test-vllm-inference.py`
- Measure throughput (tokens/sec)
- Test with various batch sizes
- Monitor GPU memory usage
- Validate output quality

**Test Script:**
```python
from vllm import LLM, SamplingParams
import time

# Initialize vLLM
print("Loading model...")
llm = LLM(
    model="meta-llama/Llama-2-7b-hf",  # or "facebook/opt-1.3b" for testing
    tensor_parallel_size=1,  # Single GPU for now
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
print("Running inference...")
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
```

**Success Metrics:**
- **Target Throughput:** >10 tokens/sec (single GPU, Llama-2-7B)
- **GPU Memory:** <32GB (should fit on single RTX 5090)

**Acceptance Criteria:**
- [ ] vLLM loads Llama-2-7B successfully
- [ ] Inference throughput >10 tokens/sec
- [ ] GPU memory usage <32GB
- [ ] Generated text is coherent
- [ ] No OOM (out of memory) errors

---

#### Task 1a.16: Basic Monitoring Setup
**Effort:** 2-3 hours
**MacBook:** ✅ Yes (can prepare, GPU required for validation)
**Dependencies:** Task 1a.8

**Description:**
Install basic monitoring tools for GPU and system health.

**Actions:**
- Create `ansible/roles/monitoring-basic` role
- Install htop, iotop, nvtop
- Install nvidia-smi systemd service (continuous logging)
- Create monitoring dashboard script: `scripts/monitor.sh`
- Configure nvidia-smi to log every 5 seconds

**Monitoring Tools:**
```yaml
monitoring_packages:
  - htop          # CPU/RAM monitoring
  - iotop         # Disk I/O monitoring
  - nvtop         # GPU monitoring (TUI)
  - sysstat       # System statistics
  - lm-sensors    # Hardware sensors
```

**Monitoring Script:**
```bash
#!/bin/bash
# scripts/monitor.sh - Simple monitoring dashboard

watch -n 2 "
echo '=== GPU Status ==='
nvidia-smi --query-gpu=index,name,temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw --format=csv,noheader

echo ''
echo '=== System Status ==='
uptime
free -h
df -h / | tail -1

echo ''
echo '=== Top Processes ==='
ps aux --sort=-%mem | head -5
"
```

**Acceptance Criteria:**
- [ ] htop, iotop, nvtop installed
- [ ] nvidia-smi logging configured
- [ ] Monitoring script functional
- [ ] Can view GPU utilization in real-time

---

#### Task 1a.17: Demo Box Setup Guide
**Effort:** 4-6 hours
**MacBook:** ✅ Yes
**Dependencies:** All above tasks

**Description:**
Create comprehensive setup guide for demo box deployment.

**Actions:**
- Document hardware requirements
- Write step-by-step deployment instructions
- Include troubleshooting section
- Create validation checklist
- Document known issues and workarounds
- Add screenshots/examples

**Document Outline:**
```markdown
# Vault Cube Demo Box Setup Guide

## Prerequisites
- Hardware requirements
- Software requirements
- Network requirements

## Quick Start
1. Download demo box image
2. Write to disk (dd or similar)
3. Boot system
4. Validate GPUs
5. Run test workloads

## Detailed Setup
- BIOS configuration
- Disk partitioning
- Network setup
- GPU driver validation
- Framework testing

## Validation
- GPU detection checklist
- PyTorch DDP test
- TensorFlow test
- vLLM inference test
- 24-hour stress test

## Troubleshooting
- GPU not detected
- NVIDIA driver errors
- Thermal throttling
- Memory errors
- Performance issues

## Known Issues
- RTX 5090 driver quirks
- BIOS settings for PCIe 5.0
- Thermal management recommendations
```

**Acceptance Criteria:**
- [ ] Setup guide complete (>2000 words)
- [ ] All deployment steps documented
- [ ] Troubleshooting section with 5+ common issues
- [ ] Validation checklist included
- [ ] Known issues documented
- [ ] Guide tested by non-author

---

## Success Criteria

### Functional Requirements
- [ ] Golden image builds successfully via Packer (<30 min build time)
- [ ] All 4× RTX 5090 GPUs detected by nvidia-smi
- [ ] Docker runs GPU-accelerated containers
- [ ] PyTorch 2.x runs multi-GPU training (ResNet-50 DDP test)
- [ ] TensorFlow 2.x runs multi-GPU training
- [ ] vLLM serves Llama-2-7B model at >10 tokens/sec
- [ ] System completes 24-hour stress test without throttling

### Performance Requirements
- [ ] PyTorch DDP scaling efficiency >80% (4 GPUs vs 1 GPU)
- [ ] vLLM throughput >10 tokens/sec (Llama-2-7B, single GPU)
- [ ] GPU utilization >90% during training workloads
- [ ] Build time <30 minutes (Packer + Ansible)

### Security Requirements
- [ ] SSH configured with key-based authentication only
- [ ] UFW firewall enabled with restrictive rules
- [ ] Non-root user can run Docker and GPU containers
- [ ] No default passwords remain in system
- [ ] fail2ban protecting SSH

### Documentation Requirements
- [ ] Setup guide enables deployment in <2 hours
- [ ] All Ansible playbooks documented
- [ ] Validation test scripts included
- [ ] Known issues documented

### Testing Requirements
- [ ] GPU detection test passes (4 GPUs visible)
- [ ] PyTorch DDP test achieves >80% scaling efficiency
- [ ] vLLM inference test completes successfully
- [ ] Docker GPU test passes
- [ ] 24-hour stress test completes without errors

---

## Deliverables

### Code Deliverables
1. **Packer Template** - `packer/ubuntu-24.04-demo-box.pkr.hcl`
2. **Ansible Playbooks** - `ansible/playbooks/site.yml` + 10+ roles
3. **Validation Scripts** - `scripts/validate-gpus.sh`, `scripts/test-pytorch-ddp.py`, `scripts/test-vllm-inference.py`
4. **Monitoring Script** - `scripts/monitor.sh`

### Image Deliverable
5. **Demo Box Golden Image** - `vault-cube-demo-box-v1.0.qcow2` (or .img)
   - Format: qcow2 or raw image
   - Size: ~50GB
   - Checksum: SHA256 provided

### Documentation Deliverables
6. **Setup Guide** - `docs/demo-box-setup-guide.md`
7. **Known Issues** - `docs/demo-box-known-issues.md`
8. **Ansible Role Documentation** - README.md in each role directory

---

## Dependencies

### Hardware Dependencies
- **Week 2 Required:** 4× NVIDIA RTX 5090 GPUs
- **Week 2 Required:** AMD Threadripper PRO 7975WX system
- **Week 2 Required:** 256GB DDR5 ECC RAM
- **Week 2 Required:** WRX90 motherboard (ASUS or ASRock)
- **Week 3 Recommended:** Full Vault Cube chassis for thermal testing

### Software Dependencies
- Ubuntu 24.04 LTS ISO (ubuntu-24.04-live-server-amd64.iso)
- NVIDIA driver 550.127.05+ (RTX 5090 support)
- CUDA toolkit 12.4.0+
- cuDNN 9.0.0+
- PyTorch 2.x (CUDA 12.4 build)
- TensorFlow 2.x (CUDA 12.4 build)
- vLLM latest stable

### External Dependencies
- Internet access for package downloads (Week 1-2)
- Packer 1.9+ installed on build machine
- Ansible 2.15+ installed on build machine
- Sufficient disk space for builds (100GB recommended)

---

## Risk Management

### Critical Risks

#### Risk 1: RTX 5090 Driver Compatibility
**Probability:** MEDIUM (40%)
**Impact:** HIGH (blocks all GPU tasks)
**Mitigation:**
- Test driver installation in VM without GPU (verify package availability)
- Have multiple driver versions ready (550.x, 560.x if available)
- Fallback: Test with RTX 4090 if RTX 5090 drivers unstable
- Allocate buffer week (Week 4) for driver debugging

#### Risk 2: GPU Hardware Delayed
**Probability:** MEDIUM (30%)
**Impact:** HIGH (blocks Week 2-3 work)
**Mitigation:**
- Confirm GPU delivery date before starting Epic 1a
- If delayed, pivot to Epic 1b preparation (air-gap setup)
- Consider procuring single RTX 5090 for early testing ($3,500)

#### Risk 3: Thermal Throttling
**Probability:** HIGH (60%)
**Impact:** MEDIUM (performance degradation)
**Mitigation:**
- Monitor GPU temperatures from first power-on
- Implement aggressive fan curves
- Run stress test progressively (1hr → 6hr → 24hr)
- Document thermal limits in known issues
- Have chassis modification plan if needed

### Medium Risks

#### Risk 4: Packer Preseed Complexity
**Probability:** HIGH (60%)
**Impact:** LOW (delays Week 1 by 1-2 days)
**Mitigation:**
- Start with cloud-init instead of preseed if issues
- Use Packer QEMU builder first (simpler than bare metal)
- Iterate on automation, manual install as fallback

#### Risk 5: CUDA Version Compatibility
**Probability:** MEDIUM (40%)
**Impact:** MEDIUM (ML frameworks may not work)
**Mitigation:**
- Validate PyTorch/TensorFlow CUDA compatibility before install
- Have CUDA 12.1 available as fallback
- Test framework installation in VM with CUDA stub

### Low Risks

#### Risk 6: Ansible Idempotency Issues
**Probability:** MEDIUM (40%)
**Impact:** LOW (annoying but not blocking)
**Mitigation:**
- Test each playbook 3× times before merging
- Use Ansible best practices (state: present, not: absent)
- Implement proper changed_when conditions

---

## Communication Plan

### Weekly Status Updates
- **Monday:** Week kickoff, blockers identification
- **Wednesday:** Mid-week progress check
- **Friday:** Week completion, next week planning

### Milestone Demos
- **End of Week 1:** Packer builds Ubuntu image automatically
- **End of Week 2:** All 4 GPUs accessible, frameworks installed
- **End of Week 3:** Demo box fully functional, ready for customer demos

### Escalation Path
- **Minor Issues:** Document in known issues, continue
- **Major Blockers:** Escalate to CTO/Product immediately
- **Hardware Issues:** Escalate to procurement team

---

## Next Steps

### Immediate Actions (Before Starting Epic 1a)
1. **Confirm GPU Hardware Delivery** - Target: Week 2, Monday
2. **Clarify Demo Box Hardware Specs** - Is it full Vault Cube or subset?
3. **Procure Ubuntu 24.04 LTS ISO** - Download and verify checksum
4. **Set Up Development Environment** - Install Packer, Ansible, VM hypervisor
5. **Initialize Git Repository** - Create directory structure

### Week 1 Focus
- Complete all MacBook-friendly tasks (1a.1 through 1a.7)
- Ensure Packer can build base Ubuntu image
- Prepare for GPU hardware arrival (Week 2)

### Preparation for Epic 1b
While Epic 1a progresses, parallel prep work for Epic 1b:
- Research CIS Benchmark for Ubuntu 24.04 LTS
- Evaluate APT mirror solutions (apt-mirror vs custom)
- Identify security hardening requirements

---

**Document Version:** 1.0
**Last Updated:** 2025-10-29
**Next Review:** End of Week 1 (adjust estimates based on actual progress)
