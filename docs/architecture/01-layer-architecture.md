# Layer Architecture - Epic 1A

**Version:** 1.0
**Date:** 2025-10-29
**Parent:** [Architecture Overview](00-architecture-overview.md)

---

## Overview

This document defines the 5-layer architecture for the Epic 1A demo box, with clear interfaces, dependencies, health checks, and rollback strategies per layer.

---

## Layer 1: Base System

### Purpose
Establish a secure, minimal Ubuntu 24.04 LTS foundation with basic tooling and security hardening.

### Scope
- Operating system installation
- User management
- Basic security (SSH, firewall, fail2ban)
- Docker Engine (CPU-only initially)
- Python 3.12 environment
- Essential packages

### Components

#### 1.1 Operating System
- **Distribution:** Ubuntu 24.04 LTS (Noble Numbat)
- **Kernel:** 6.8.0-45-generic (or latest)
- **Architecture:** x86_64
- **Disk:** 50GB minimum, ext4 filesystem
- **Partitioning:**
  - `/` - 40GB (root)
  - `/boot` - 1GB
  - `/home` - Remaining space
  - `swap` - 8GB

#### 1.2 User Configuration
- **Primary User:** `vaultadmin`
  - UID: 1000
  - Groups: `sudo`, `docker` (docker added later)
  - Shell: `/bin/bash`
  - Home: `/home/vaultadmin`
  - SSH Key: Public key injected during Packer build

- **Root User:**
  - SSH login: **DISABLED**
  - Password authentication: **DISABLED**
  - Sudo access: Via `vaultadmin` only

#### 1.3 Essential Packages
```yaml
system_packages:
  - build-essential
  - git
  - curl
  - wget
  - vim
  - nano
  - htop
  - iotop
  - net-tools
  - openssh-server
  - ca-certificates
  - gnupg
  - lsb-release
  - software-properties-common
  - apt-transport-https
```

#### 1.4 Security Hardening

**SSH Configuration:**
```
Port: 22
PermitRootLogin: no
PasswordAuthentication: no
PubkeyAuthentication: yes
AllowUsers: vaultadmin
ClientAliveInterval: 300
ClientAliveCountMax: 2
```

**Firewall (UFW):**
```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw enable
```

**Fail2ban:**
```ini
[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 600
```

**Automatic Updates:**
```yaml
unattended_upgrades:
  enabled: true
  automatic_reboot: false
  security_updates: true
  all_updates: false
```

#### 1.5 Docker Engine
- **Version:** 24.0+
- **Runtime:** containerd
- **Purpose:** Foundation for GPU containers (Layer 3)
- **Configuration:**
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

#### 1.6 Python Environment
- **Version:** Python 3.12 (Ubuntu 24.04 default)
- **Package Manager:** pip 24+
- **Packages:**
  ```
  python3
  python3-pip
  python3-venv
  python3-dev
  python-is-python3
  ```

### Layer Interfaces

**Input:** None (base layer)

**Output:**
- SSH access on port 22 (key-based)
- Docker daemon running (CPU-only)
- Python 3.12 available
- User `vaultadmin` with sudo access

### Health Checks

```bash
#!/bin/bash
# scripts/health-check-layer1.sh

set -e

echo "=== Layer 1 Health Check ==="

# Check OS version
os_version=$(lsb_release -d | awk -F'\t' '{print $2}')
echo "✓ OS: $os_version"

# Check user exists
id vaultadmin > /dev/null 2>&1
echo "✓ User: vaultadmin exists"

# Check SSH service
systemctl is-active --quiet sshd
echo "✓ SSH: sshd running"

# Check firewall
ufw status | grep -q "Status: active"
echo "✓ Firewall: UFW active"

# Check Docker
docker --version > /dev/null 2>&1
systemctl is-active --quiet docker
echo "✓ Docker: $(docker --version)"

# Check Python
python_version=$(python3 --version)
echo "✓ Python: $python_version"

echo "=== Layer 1 Health Check PASSED ==="
```

### Rollback Strategy

**Scenario:** Layer 1 provisioning fails (e.g., package installation error)

**Recovery:**
1. Revert to base Packer-built image (pre-Ansible)
2. Review Ansible logs: `ansible-playbook site.yml -v`
3. Fix broken task in playbook
4. Re-run: `ansible-playbook site.yml --start-at-task="Failed Task"`

**Snapshot Point:** After successful Packer build, before Ansible provisioning

### Validation Tests

```bash
# Test: SSH key authentication
ssh vaultadmin@localhost echo "SSH OK"

# Test: Docker hello-world
docker run hello-world

# Test: Python import
python -c "import sys; assert sys.version_info >= (3, 12)"

# Test: Firewall rules
sudo ufw status numbered | grep "22/tcp"

# Test: Idempotency
ansible-playbook ansible/playbooks/site.yml --tags layer1 --check
```

### Time Estimate
- **Packer build:** 15 minutes
- **Ansible provisioning:** 3 minutes
- **Validation:** 2 minutes
- **Total:** ~20 minutes

---

## Layer 2: Driver Stack

### Purpose
Install NVIDIA GPU drivers, CUDA toolkit, and cuDNN for GPU compute capability.

### Dependencies
- **Layer 1:** Base system, kernel headers, build tools
- **Hardware:** 4× RTX 5090 GPUs installed

### Scope
- NVIDIA driver 550.127.05+
- CUDA toolkit 12.4.0+
- cuDNN 9.0.0+
- Kernel module configuration
- Driver persistence

### Components

#### 2.1 NVIDIA Driver
- **Version:** 550.127.05 or newer
- **Installation Method:** APT package from NVIDIA repository
- **Repository:** `https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/`
- **Package:** `nvidia-driver-550`

**Installation:**
```yaml
- name: Add NVIDIA CUDA repository
  apt_repository:
    repo: deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/ /
    state: present
    filename: cuda

- name: Install NVIDIA driver
  apt:
    name: nvidia-driver-550
    state: present
    update_cache: yes
```

**Kernel Module Loading:**
```bash
# /etc/modules-load.d/nvidia.conf
nvidia
nvidia-uvm
nvidia-drm
```

**Driver Persistence:**
```bash
# Enable NVIDIA persistence daemon
sudo systemctl enable nvidia-persistenced
sudo systemctl start nvidia-persistenced
```

#### 2.2 CUDA Toolkit
- **Version:** 12.4.0+
- **Installation Method:** APT package
- **Package:** `cuda-toolkit-12-4`

**Installation:**
```yaml
- name: Install CUDA toolkit
  apt:
    name: cuda-toolkit-12-4
    state: present
```

**Environment Variables:**
```bash
# /etc/profile.d/cuda.sh
export PATH=/usr/local/cuda-12.4/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-12.4/lib64:$LD_LIBRARY_PATH
```

#### 2.3 cuDNN
- **Version:** 9.0.0+
- **Installation Method:** APT package from NVIDIA repository
- **Package:** `libcudnn9-cuda-12`

**Installation:**
```yaml
- name: Install cuDNN
  apt:
    name: libcudnn9-cuda-12
    state: present
```

### Layer Interfaces

**Input:**
- Layer 1 base system
- Kernel headers installed
- Build tools available

**Output:**
- `nvidia-smi` command available
- CUDA compiler (`nvcc`) in PATH
- cuDNN libraries available
- 4× RTX 5090 GPUs accessible

### Health Checks

```bash
#!/bin/bash
# scripts/health-check-layer2.sh

set -e

echo "=== Layer 2 Health Check ==="

# Check NVIDIA driver loaded
lsmod | grep -q nvidia
echo "✓ NVIDIA kernel module loaded"

# Check nvidia-smi
nvidia-smi > /dev/null 2>&1
echo "✓ nvidia-smi operational"

# Check GPU count
GPU_COUNT=$(nvidia-smi --query-gpu=count --format=csv,noheader | head -1)
if [ "$GPU_COUNT" != "4" ]; then
    echo "✗ ERROR: Expected 4 GPUs, found $GPU_COUNT"
    exit 1
fi
echo "✓ GPU Count: $GPU_COUNT"

# Check CUDA version
nvcc --version > /dev/null 2>&1
CUDA_VERSION=$(nvcc --version | grep "release" | awk '{print $5}' | sed 's/,//')
echo "✓ CUDA Version: $CUDA_VERSION"

# Check cuDNN
ldconfig -p | grep -q libcudnn
echo "✓ cuDNN libraries found"

# Check GPU temperatures (should be reasonable)
MAX_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader | sort -nr | head -1)
echo "✓ Max GPU Temperature: ${MAX_TEMP}°C"
if [ "$MAX_TEMP" -gt 90 ]; then
    echo "⚠ WARNING: GPU temperature >90°C"
fi

# Check for GPU errors
GPU_ERRORS=$(dmesg | grep -i nvidia | grep -i error | wc -l)
if [ "$GPU_ERRORS" -gt 0 ]; then
    echo "⚠ WARNING: Found $GPU_ERRORS GPU errors in dmesg"
fi

echo "=== Layer 2 Health Check PASSED ==="
```

### Rollback Strategy

**Scenario:** Driver installation fails or causes kernel panic

**Recovery:**
1. Boot into recovery mode (previous kernel)
2. Remove NVIDIA packages:
   ```bash
   sudo apt purge nvidia-* cuda-* libcudnn*
   sudo apt autoremove
   ```
3. Rollback to Layer 1 image snapshot
4. Try alternate driver version (e.g., 545 instead of 550)

**Snapshot Point:** After Layer 1 complete, before NVIDIA driver installation

### Validation Tests

```bash
# Test: GPU detection
nvidia-smi -L | grep "RTX 5090"

# Test: GPU memory
nvidia-smi --query-gpu=memory.total --format=csv,noheader | grep "32768"

# Test: CUDA compilation
cat > test_cuda.cu << EOF
#include <stdio.h>
__global__ void hello() { printf("Hello from GPU!\\n"); }
int main() { hello<<<1,1>>>(); cudaDeviceSynchronize(); return 0; }
EOF
nvcc test_cuda.cu -o test_cuda
./test_cuda

# Test: PCIe link speed
nvidia-smi --query-gpu=pcie.link.gen.current --format=csv,noheader | grep "5"

# Test: Driver persistence
systemctl is-active --quiet nvidia-persistenced
```

### Known Issues

1. **RTX 5090 New Hardware:** Driver may have bugs, monitor NVIDIA driver updates
2. **Kernel Updates:** Automatic kernel updates may break NVIDIA driver, DKMS should rebuild
3. **Secure Boot:** May need to disable or sign NVIDIA kernel modules

### Time Estimate
- **Driver download:** 2 minutes
- **Driver installation:** 4 minutes
- **System reboot:** 1 minute
- **Validation:** 1 minute
- **Total:** ~8 minutes

---

## Layer 3: GPU Runtime

### Purpose
Enable Docker containers to access GPUs via NVIDIA Container Toolkit.

### Dependencies
- **Layer 2:** NVIDIA drivers installed and functional
- **Layer 1:** Docker Engine installed

### Scope
- NVIDIA Container Toolkit installation
- Docker daemon GPU configuration
- GPU runtime testing

### Components

#### 3.1 NVIDIA Container Toolkit
- **Version:** Latest stable (1.14+)
- **Repository:** `https://nvidia.github.io/libnvidia-container`
- **Package:** `nvidia-container-toolkit`

**Installation:**
```yaml
- name: Add NVIDIA Container Toolkit repository
  shell: |
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
      sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
      sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

- name: Install NVIDIA Container Toolkit
  apt:
    name: nvidia-container-toolkit
    state: present
    update_cache: yes
```

#### 3.2 Docker Daemon Configuration

**Update `/etc/docker/daemon.json`:**
```json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "live-restore": true,
  "runtimes": {
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  },
  "default-runtime": "nvidia"
}
```

**Restart Docker:**
```bash
sudo systemctl restart docker
```

### Layer Interfaces

**Input:**
- Layer 2 NVIDIA drivers
- Layer 1 Docker Engine

**Output:**
- Docker containers can access GPUs with `--gpus all`
- NVIDIA runtime set as default

### Health Checks

```bash
#!/bin/bash
# scripts/health-check-layer3.sh

set -e

echo "=== Layer 3 Health Check ==="

# Check NVIDIA Container Toolkit installed
nvidia-ctk --version > /dev/null 2>&1
echo "✓ NVIDIA Container Toolkit: $(nvidia-ctk --version)"

# Check Docker daemon has nvidia runtime
docker info | grep -q "nvidia"
echo "✓ Docker: NVIDIA runtime configured"

# Test GPU access from container
docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu24.04 nvidia-smi > /dev/null 2>&1
echo "✓ Container GPU Access: Working"

# Verify all GPUs accessible from container
GPU_COUNT_CONTAINER=$(docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu24.04 nvidia-smi --query-gpu=count --format=csv,noheader | head -1)
if [ "$GPU_COUNT_CONTAINER" != "4" ]; then
    echo "✗ ERROR: Container sees $GPU_COUNT_CONTAINER GPUs, expected 4"
    exit 1
fi
echo "✓ Container GPU Count: $GPU_COUNT_CONTAINER"

echo "=== Layer 3 Health Check PASSED ==="
```

### Rollback Strategy

**Scenario:** Docker GPU access broken

**Recovery:**
1. Check Docker daemon configuration:
   ```bash
   cat /etc/docker/daemon.json
   ```
2. Remove and reinstall NVIDIA Container Toolkit:
   ```bash
   sudo apt purge nvidia-container-toolkit
   sudo apt install nvidia-container-toolkit
   ```
3. Restart Docker:
   ```bash
   sudo systemctl restart docker
   ```
4. Rollback to Layer 2 snapshot if unrecoverable

### Validation Tests

```bash
# Test: NVIDIA runtime available
docker info 2>/dev/null | grep "Runtimes:" -A 5 | grep nvidia

# Test: GPU container basics
docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu24.04 nvidia-smi

# Test: Multi-GPU access
docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu24.04 nvidia-smi -L

# Test: GPU memory allocation in container
docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu24.04 bash -c "
nvidia-smi --query-gpu=memory.total --format=csv,noheader
"
```

### Time Estimate
- **Toolkit installation:** 2 minutes
- **Docker restart:** 30 seconds
- **Validation:** 1 minute
- **Total:** ~4 minutes

---

## Layer 4: AI Frameworks

### Purpose
Install PyTorch, TensorFlow, and vLLM with GPU acceleration.

### Dependencies
- **Layer 3:** Docker GPU runtime
- **Layer 2:** CUDA 12.4+, cuDNN 9.x
- **Layer 1:** Python 3.12

### Scope
- PyTorch 2.x with CUDA 12.4
- TensorFlow 2.x with CUDA 12.4
- vLLM for LLM inference
- NumPy, Pandas, Scikit-learn

### Components

#### 4.1 PyTorch 2.x
- **Version:** 2.1.0+ with CUDA 12.4 support
- **Installation:**
  ```bash
  pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
  ```

**Validation:**
```python
import torch
print(f"PyTorch: {torch.__version__}")
print(f"CUDA Available: {torch.cuda.is_available()}")
print(f"CUDA Version: {torch.version.cuda}")
print(f"GPU Count: {torch.cuda.device_count()}")
for i in range(torch.cuda.device_count()):
    print(f"  GPU {i}: {torch.cuda.get_device_name(i)}")
```

#### 4.2 TensorFlow 2.x
- **Version:** 2.14.0+ with CUDA 12.4 support
- **Installation:**
  ```bash
  pip3 install tensorflow[and-cuda]
  ```

**Validation:**
```python
import tensorflow as tf
print(f"TensorFlow: {tf.__version__}")
print(f"GPU Devices: {tf.config.list_physical_devices('GPU')}")
print(f"GPU Count: {len(tf.config.list_physical_devices('GPU'))}")
```

#### 4.3 vLLM
- **Version:** Latest stable (0.2.1+)
- **Installation:**
  ```bash
  pip3 install vllm
  ```

**Validation:**
```python
from vllm import LLM, SamplingParams
llm = LLM(model="facebook/opt-125m")
prompts = ["Hello, my name is"]
outputs = llm.generate(prompts, SamplingParams(temperature=0.8))
print(outputs[0].outputs[0].text)
```

#### 4.4 Supporting Libraries
```bash
pip3 install numpy pandas scikit-learn matplotlib jupyter
```

### Layer Interfaces

**Input:**
- Layer 2 CUDA 12.4, cuDNN 9.x
- Layer 1 Python 3.12

**Output:**
- PyTorch GPU acceleration working
- TensorFlow GPU acceleration working
- vLLM inference capability

### Health Checks

```bash
#!/bin/bash
# scripts/health-check-layer4.sh

set -e

echo "=== Layer 4 Health Check ==="

# Check PyTorch
python3 -c "
import torch
assert torch.cuda.is_available(), 'PyTorch CUDA not available'
assert torch.cuda.device_count() == 4, f'Expected 4 GPUs, found {torch.cuda.device_count()}'
print(f'✓ PyTorch {torch.__version__} with {torch.cuda.device_count()} GPUs')
"

# Check TensorFlow
python3 -c "
import tensorflow as tf
gpus = tf.config.list_physical_devices('GPU')
assert len(gpus) == 4, f'Expected 4 GPUs, found {len(gpus)}'
print(f'✓ TensorFlow {tf.__version__} with {len(gpus)} GPUs')
"

# Check vLLM
python3 -c "
from vllm import LLM
print('✓ vLLM installed and importable')
"

echo "=== Layer 4 Health Check PASSED ==="
```

### Rollback Strategy

**Scenario:** Framework installation fails or version incompatible

**Recovery:**
1. Uninstall broken framework:
   ```bash
   pip3 uninstall torch torchvision torchaudio tensorflow vllm
   ```
2. Verify CUDA version compatibility:
   ```bash
   nvcc --version  # Should be 12.4.x
   ```
3. Reinstall with correct CUDA version:
   ```bash
   pip3 install torch --index-url https://download.pytorch.org/whl/cu124
   ```
4. If unrecoverable, rollback to Layer 3 snapshot

### Validation Tests

```bash
# Test: PyTorch GPU tensor operations
python3 -c "
import torch
x = torch.randn(1000, 1000).cuda()
y = torch.randn(1000, 1000).cuda()
z = torch.matmul(x, y)
print(f'PyTorch GPU operation: {z.shape}')
"

# Test: TensorFlow GPU operations
python3 -c "
import tensorflow as tf
with tf.device('/GPU:0'):
    a = tf.constant([[1.0, 2.0], [3.0, 4.0]])
    b = tf.constant([[1.0, 1.0], [0.0, 1.0]])
    c = tf.matmul(a, b)
    print(f'TensorFlow GPU operation: {c}')
"

# Test: vLLM inference (small model)
python3 scripts/test-vllm-inference.py
```

### Time Estimate
- **PyTorch download & install:** 4 minutes
- **TensorFlow download & install:** 3 minutes
- **vLLM download & install:** 2 minutes
- **Validation:** 1 minute
- **Total:** ~10 minutes

---

## Layer 5: Validation & Monitoring

### Purpose
Provide comprehensive testing and real-time monitoring capabilities.

### Dependencies
- **Layer 4:** AI frameworks installed
- **Layer 2:** NVIDIA drivers
- **Layer 1:** Base system

### Scope
- GPU detection validation
- Multi-GPU training tests
- Inference performance tests
- Monitoring tools (htop, nvtop)
- 24-hour stress testing

### Components

#### 5.1 Validation Scripts

**GPU Detection** (`scripts/validate-gpus.sh`)
- Check 4 GPUs present
- Verify GPU memory (32GB each)
- Check PCIe link speed
- Monitor temperatures

**PyTorch DDP Test** (`scripts/test-pytorch-ddp.py`)
- Train ResNet-50 on 4 GPUs
- Measure scaling efficiency
- Target: >80% efficiency

**vLLM Inference Test** (`scripts/test-vllm-inference.py`)
- Load Llama-2-7B model
- Measure throughput (tokens/sec)
- Target: >10 tokens/sec

#### 5.2 Monitoring Tools

**Install:**
```yaml
- name: Install monitoring tools
  apt:
    name:
      - htop
      - iotop
      - sysstat
      - lm-sensors
    state: present

- name: Install nvtop (GPU monitoring)
  apt:
    name: nvtop
    state: present
```

**Monitoring Script** (`scripts/monitor.sh`):
```bash
#!/bin/bash
watch -n 2 "
echo '=== GPU Status ==='
nvidia-smi --query-gpu=index,name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv

echo ''
echo '=== System Status ==='
uptime
free -h
"
```

#### 5.3 Stress Testing

**24-Hour Thermal Test** (`scripts/stress-test-24hr.sh`):
```bash
#!/bin/bash
# Load all 4 GPUs continuously for 24 hours

for gpu in 0 1 2 3; do
  CUDA_VISIBLE_DEVICES=$gpu python3 -c "
import torch
x = torch.randn(30000, 30000).cuda()
while True:
    y = torch.matmul(x, x)
    torch.cuda.synchronize()
" &
done

echo "Stress test running. Monitor with: watch -n 5 nvidia-smi"
echo "Press Ctrl+C to stop after 24 hours."
```

### Layer Interfaces

**Input:**
- All previous layers (1-4)

**Output:**
- Comprehensive validation reports
- Performance benchmarks
- Monitoring dashboards
- Stress test results

### Health Checks

```bash
#!/bin/bash
# scripts/health-check-layer5.sh

set -e

echo "=== Layer 5 Health Check ==="

# Check validation scripts exist
test -f scripts/validate-gpus.sh
test -f scripts/test-pytorch-ddp.py
test -f scripts/test-vllm-inference.py
echo "✓ Validation scripts present"

# Check monitoring tools installed
which htop > /dev/null
which nvtop > /dev/null
echo "✓ Monitoring tools installed"

# Run quick validation
bash scripts/validate-gpus.sh
echo "✓ GPU validation passed"

echo "=== Layer 5 Health Check PASSED ==="
```

### Validation Tests

```bash
# Test: Full validation suite
bash scripts/validate-gpus.sh
python3 scripts/test-pytorch-ddp.py
python3 scripts/test-vllm-inference.py

# Test: Monitoring tools
htop --version
nvtop --version
```

### Time Estimate
- **Validation script testing:** 20 minutes
- **24-hour stress test:** 24 hours (separate)
- **Total (excluding stress):** ~20 minutes

---

## Layer Integration Matrix

| Layer | Depends On | Provides To | Test Interface |
|-------|------------|-------------|----------------|
| **Layer 1** | None | Base system | SSH, Docker hello-world |
| **Layer 2** | Layer 1 | GPU drivers | nvidia-smi |
| **Layer 3** | Layers 1, 2 | GPU containers | docker run --gpus all |
| **Layer 4** | Layers 1-3 | AI frameworks | PyTorch/TF import, GPU ops |
| **Layer 5** | Layers 1-4 | Validation | Test scripts pass |

---

## Complete Build Flow

```
Packer Build (Layer 1 base)
    │
    ▼
Ansible: Layer 1 (base system, Docker, Python)
    │
    ▼
Health Check: Layer 1 ✓
    │
    ▼
Ansible: Layer 2 (NVIDIA drivers, CUDA)
    │
    ▼
System Reboot
    │
    ▼
Health Check: Layer 2 ✓
    │
    ▼
Ansible: Layer 3 (NVIDIA Container Toolkit)
    │
    ▼
Docker Restart
    │
    ▼
Health Check: Layer 3 ✓
    │
    ▼
Ansible: Layer 4 (PyTorch, TensorFlow, vLLM)
    │
    ▼
Health Check: Layer 4 ✓
    │
    ▼
Ansible: Layer 5 (Validation scripts, monitoring)
    │
    ▼
Health Check: Layer 5 ✓
    │
    ▼
Full Integration Testing
    │
    ▼
Golden Image v1.0 🎉
```

**Total Build Time:** ~30 minutes (excluding 24-hour stress test)

---

**Document Version:** 1.0
**Last Updated:** 2025-10-29
**Next Review:** After Week 1 implementation
