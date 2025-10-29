# Build Pipeline Architecture - Epic 1A

**Version:** 1.0
**Date:** 2025-10-29
**Parent:** [Architecture Overview](00-architecture-overview.md)

---

## Overview

This document defines the automated build pipeline for Epic 1A golden image creation, including stages, validation gates, caching strategies, and optimization techniques.

---

## Pipeline Architecture

### High-Level Flow

```
┌────────────────────────────────────────────────────────────────┐
│                    GOLDEN IMAGE BUILD PIPELINE                  │
└────────────────────────────────────────────────────────────────┘

┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  Source  │───▶│  Packer  │───▶│  Ansible │───▶│   Test   │
│   Code   │    │  Build   │    │Provision │    │Validate  │
└──────────┘    └──────────┘    └──────────┘    └──────────┘
                      │               │               │
                      ▼               ▼               ▼
                ┌──────────┐    ┌──────────┐    ┌──────────┐
                │   Base   │    │Configured│    │ Validated│
                │  Image   │    │  Image   │    │  Golden  │
                │ (.qcow2) │    │ (Layers  │    │  Image   │
                └──────────┘    │ 1-5 Done)│    │ (v1.0)   │
                                └──────────┘    └──────────┘
```

---

## Stage 1: Source Code & Pre-Build

### Purpose
Prepare source code and validate templates before build.

### Activities

1. **Git Repository Checkout**
   ```bash
   git clone https://github.com/vault-ai/cube-golden-image.git
   cd cube-golden-image
   git checkout main
   ```

2. **Packer Template Validation**
   ```bash
   packer validate packer/ubuntu-24.04-demo-box.pkr.hcl
   ```

3. **Ansible Syntax Check**
   ```bash
   ansible-playbook ansible/playbooks/site.yml --syntax-check
   ```

4. **Ansible Lint** (optional, for quality)
   ```bash
   ansible-lint ansible/playbooks/site.yml
   ```

### Validation Gate

**Pass Criteria:**
- Packer template validation succeeds
- Ansible syntax check passes
- No critical linting errors

**On Failure:**
- Fix template/playbook errors
- Re-run validation
- Do not proceed to Packer build

### Time Estimate
- **Checkout:** 30 seconds
- **Validation:** 1 minute
- **Total:** ~2 minutes

---

## Stage 2: Packer Build (Base Image Creation)

### Purpose
Automate Ubuntu 24.04 LTS installation and create base image.

### Packer Template Structure

```hcl
# packer/ubuntu-24.04-demo-box.pkr.hcl

packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "qemu" "ubuntu-2404" {
  # ISO Configuration
  iso_url          = "https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso"
  iso_checksum     = "sha256:8762f7e74e4d64d72fceb5f70682e6b069932deedb4949c6975d0f0fe0a91be3"

  # VM Configuration
  memory           = 8192
  cpus             = 4
  disk_size        = "50G"
  disk_interface   = "virtio"
  format           = "qcow2"
  accelerator      = "kvm"  # or "hvf" for macOS

  # Network
  net_device       = "virtio-net"

  # SSH Configuration
  ssh_username     = "vaultadmin"
  ssh_password     = "temp-build-password"  # Removed after build
  ssh_timeout      = "20m"
  ssh_handshake_attempts = 10

  # Shutdown
  shutdown_command = "echo 'vaultadmin' | sudo -S shutdown -P now"

  # Output
  output_directory = "output-qemu"
  vm_name          = "vault-cube-demo-box-v1.0"

  # Boot Configuration
  boot_wait        = "5s"
  boot_command     = [
    "<esc><wait>",
    "autoinstall ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/",
    "<enter>"
  ]

  # HTTP server for cloud-init
  http_directory   = "packer/http"
}

build {
  sources = ["source.qemu.ubuntu-2404"]

  # Provisioner: Ansible (Layer 1-5)
  provisioner "ansible" {
    playbook_file = "ansible/playbooks/site.yml"
    use_proxy     = false
    ansible_env_vars = [
      "ANSIBLE_HOST_KEY_CHECKING=False"
    ]
  }

  # Post-processor: Create manifest
  post-processor "manifest" {
    output     = "output-qemu/manifest.json"
    strip_path = true
  }

  # Post-processor: Checksum
  post-processor "checksum" {
    checksum_types = ["sha256"]
    output         = "output-qemu/{{.BuildName}}.{{.ChecksumType}}"
  }
}
```

### Cloud-Init Configuration

**File:** `packer/http/user-data`

```yaml
#cloud-config
autoinstall:
  version: 1
  locale: en_US.UTF-8
  keyboard:
    layout: us
  network:
    network:
      version: 2
      ethernets:
        enp0s3:
          dhcp4: true
  storage:
    layout:
      name: lvm
  identity:
    hostname: vault-cube-demo
    username: vaultadmin
    password: "$6$rounds=4096$saltsalt$hashedpassword"  # Generated
  ssh:
    install-server: true
    allow-pw: true
  packages:
    - openssh-server
    - vim
    - curl
  late-commands:
    - echo 'vaultadmin ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/vaultadmin
```

**File:** `packer/http/meta-data`
```yaml
instance-id: vault-cube-demo-box
local-hostname: vault-cube-demo
```

### Build Process

**Execution:**
```bash
cd packer/
packer build ubuntu-24.04-demo-box.pkr.hcl
```

**Build Steps:**
1. Download Ubuntu ISO (cached if previously downloaded)
2. Create VM with QEMU/KVM
3. Boot from ISO with autoinstall parameters
4. Cloud-init automates Ubuntu installation
5. System reboots
6. SSH becomes available
7. Packer connects via SSH
8. Ansible provisioner invoked (see Stage 3)
9. Image finalized and saved to `output-qemu/`

### Validation Gate

**Pass Criteria:**
- Packer build completes without errors
- Base image file created (`.qcow2`)
- SSH access works
- Image boots successfully

**On Failure:**
- Check Packer logs: `packer build -debug`
- Verify cloud-init configuration
- Check VM console output
- Retry build

### Time Estimate
- **ISO download:** 2 minutes (cached after first run)
- **Ubuntu installation:** 10 minutes
- **SSH wait:** 2 minutes
- **Image finalization:** 1 minute
- **Total:** ~15 minutes (first run), ~10 minutes (cached)

---

## Stage 3: Ansible Provisioning (Layers 1-5)

### Purpose
Configure base image with all 5 layers (base system → validation).

### Ansible Playbook Structure

**Main Playbook:** `ansible/playbooks/site.yml`

```yaml
---
- name: Provision Vault Cube Demo Box
  hosts: default
  become: yes
  gather_facts: yes

  roles:
    # Layer 1: Base System
    - role: common
      tags: ['layer1', 'common']

    - role: users
      tags: ['layer1', 'users']

    - role: security
      tags: ['layer1', 'security']

    - role: docker
      tags: ['layer1', 'docker']

    - role: python
      tags: ['layer1', 'python']

    # Layer 2: Driver Stack
    - role: nvidia-drivers
      tags: ['layer2', 'nvidia']
      when: ansible_local.gpu_hardware_present | default(false)

    # Layer 3: GPU Runtime
    - role: nvidia-container-toolkit
      tags: ['layer3', 'nvidia-runtime']
      when: ansible_local.gpu_hardware_present | default(false)

    # Layer 4: AI Frameworks
    - role: pytorch
      tags: ['layer4', 'pytorch']
      when: ansible_local.gpu_hardware_present | default(false)

    - role: tensorflow
      tags: ['layer4', 'tensorflow']
      when: ansible_local.gpu_hardware_present | default(false)

    - role: vllm
      tags: ['layer4', 'vllm']
      when: ansible_local.gpu_hardware_present | default(false)

    # Layer 5: Validation & Monitoring
    - role: monitoring
      tags: ['layer5', 'monitoring']

    - role: validation-scripts
      tags: ['layer5', 'validation']

  post_tasks:
    - name: Run Layer 1 health check
      command: /usr/local/bin/health-check-layer1.sh
      tags: ['validation']

    - name: Run Layer 2 health check
      command: /usr/local/bin/health-check-layer2.sh
      when: ansible_local.gpu_hardware_present | default(false)
      tags: ['validation']

    # ... Additional health checks
```

### Provisioning Phases

#### Phase 1: Layer 1 (Base System) - 3 minutes

**Activities:**
- System update (`apt update && apt upgrade`)
- Install essential packages
- Create users and configure sudo
- SSH hardening
- UFW firewall setup
- fail2ban installation
- Docker Engine installation
- Python 3.12 environment setup

**Ansible Roles:**
- `common`
- `users`
- `security`
- `docker`
- `python`

**Validation:**
```bash
ansible-playbook site.yml --tags layer1 --check
```

#### Phase 2: Layer 2 (Driver Stack) - 4 minutes

**Activities:**
- Add NVIDIA repository
- Install NVIDIA driver 550+
- Install CUDA toolkit 12.4+
- Install cuDNN 9.x
- Configure kernel modules
- Enable driver persistence
- **System reboot required**

**Ansible Roles:**
- `nvidia-drivers`

**Validation:**
```bash
nvidia-smi
nvcc --version
```

**Note:** This phase requires GPU hardware. Skipped on MacBook development.

#### Phase 3: Layer 3 (GPU Runtime) - 2 minutes

**Activities:**
- Install NVIDIA Container Toolkit
- Reconfigure Docker daemon (nvidia runtime)
- Restart Docker service
- Test GPU container access

**Ansible Roles:**
- `nvidia-container-toolkit`

**Validation:**
```bash
docker run --rm --gpus all nvidia/cuda:12.4.0-base nvidia-smi
```

#### Phase 4: Layer 4 (AI Frameworks) - 6 minutes

**Activities:**
- Install PyTorch 2.x (CUDA 12.4 build)
- Install TensorFlow 2.x (CUDA 12.4 build)
- Install vLLM
- Install supporting libraries (NumPy, Pandas, etc.)

**Ansible Roles:**
- `pytorch`
- `tensorflow`
- `vllm`

**Validation:**
```python
import torch, tensorflow as tf
print(torch.cuda.is_available(), len(tf.config.list_physical_devices('GPU')))
```

#### Phase 5: Layer 5 (Validation & Monitoring) - 1 minute

**Activities:**
- Install monitoring tools (htop, nvtop)
- Copy validation scripts to `/usr/local/bin/`
- Create monitoring dashboard script

**Ansible Roles:**
- `monitoring`
- `validation-scripts`

**Validation:**
```bash
/usr/local/bin/health-check-layer1.sh
/usr/local/bin/validate-gpus.sh
```

### Parallel Execution Optimization

**Strategy:** Use Ansible async tasks for independent operations.

**Example:**
```yaml
# Install multiple packages in parallel
- name: Install ML libraries in parallel
  pip:
    name: "{{ item }}"
    state: present
  loop:
    - torch
    - tensorflow
    - vllm
    - numpy
    - pandas
  async: 600
  poll: 0
  register: pip_install

- name: Wait for parallel installations
  async_status:
    jid: "{{ item.ansible_job_id }}"
  loop: "{{ pip_install.results }}"
  register: jobs
  until: jobs.finished
  retries: 60
  delay: 10
```

### Validation Gate

**Pass Criteria:**
- All Ansible tasks succeed
- Health checks pass for each layer
- No failed tasks in playbook output

**On Failure:**
- Check Ansible logs: `ansible-playbook site.yml -vvv`
- Run specific layer: `ansible-playbook site.yml --tags layer2`
- Fix failing tasks
- Re-run from failed point: `ansible-playbook site.yml --start-at-task="Failed Task"`

### Time Estimate
- **Layer 1:** 3 minutes
- **Layer 2:** 4 minutes (+ 1 min reboot)
- **Layer 3:** 2 minutes
- **Layer 4:** 6 minutes
- **Layer 5:** 1 minute
- **Total:** ~17 minutes

---

## Stage 4: Testing & Validation

### Purpose
Comprehensive validation of all layers and performance benchmarking.

### Test Suites

#### 1. GPU Detection Test (2 minutes)

**Script:** `scripts/validate-gpus.sh`

**Tests:**
- All 4 GPUs detected
- GPU memory correct (32GB per GPU)
- PCIe link speed verified (Gen5 x16)
- Idle temperatures reasonable (<60°C)
- No GPU errors in dmesg

**Execution:**
```bash
bash scripts/validate-gpus.sh
```

**Pass Criteria:** Exit code 0, all checks pass

---

#### 2. PyTorch Multi-GPU Test (10 minutes)

**Script:** `scripts/test-pytorch-ddp.py`

**Tests:**
- DistributedDataParallel (DDP) initialization
- ResNet-50 training on 4 GPUs
- Scaling efficiency >80%
- GPU utilization >90%

**Execution:**
```bash
python3 scripts/test-pytorch-ddp.py
```

**Pass Criteria:**
- DDP training completes without errors
- Scaling efficiency >80%
- No NCCL errors in logs

---

#### 3. TensorFlow GPU Test (5 minutes)

**Script:** `scripts/test-tensorflow-gpu.py`

**Tests:**
- Multi-GPU device listing
- GPU tensor operations
- Memory allocation across GPUs

**Execution:**
```bash
python3 scripts/test-tensorflow-gpu.py
```

**Pass Criteria:** All GPUs detected, operations succeed

---

#### 4. vLLM Inference Test (10 minutes)

**Script:** `scripts/test-vllm-inference.py`

**Tests:**
- Load Llama-2-7B (or smaller test model)
- Inference throughput >10 tokens/sec
- GPU memory usage <32GB
- Output quality validation

**Execution:**
```bash
python3 scripts/test-vllm-inference.py
```

**Pass Criteria:**
- Model loads successfully
- Throughput >10 tokens/sec
- No OOM errors

---

#### 5. Docker GPU Integration Test (3 minutes)

**Script:** `scripts/test-docker-gpu.sh`

**Tests:**
- Container GPU access with `--gpus all`
- Multi-container GPU sharing
- NVIDIA runtime functional

**Execution:**
```bash
bash scripts/test-docker-gpu.sh
```

**Pass Criteria:** All containers can access GPUs

---

### Test Execution Flow

```
Run All Tests in Sequence
    │
    ├─► GPU Detection Test (2 min)
    │       ├─ PASS → Continue
    │       └─ FAIL → Stop, investigate
    │
    ├─► PyTorch DDP Test (10 min)
    │       ├─ PASS → Continue
    │       └─ FAIL → Stop, investigate
    │
    ├─► TensorFlow Test (5 min)
    │       ├─ PASS → Continue
    │       └─ FAIL → Stop, investigate
    │
    ├─► vLLM Inference Test (10 min)
    │       ├─ PASS → Continue
    │       └─ FAIL → Stop, investigate
    │
    └─► Docker GPU Test (3 min)
            ├─ PASS → All Tests PASSED ✓
            └─ FAIL → Investigate
```

### Validation Gate

**Pass Criteria:**
- All 5 test suites pass
- No errors in system logs
- Performance targets met

**On Failure:**
- Review test logs
- Check GPU health: `nvidia-smi`
- Inspect system logs: `dmesg | tail -100`
- Re-run failing test in isolation
- Rollback to previous layer if unrecoverable

### Time Estimate
- **Total:** ~30 minutes (all tests)

---

## Stage 5: Image Finalization

### Purpose
Create final golden image artifact with versioning and metadata.

### Activities

1. **Cleanup Build Artifacts**
   ```bash
   # Remove SSH temporary passwords
   sudo passwd -d vaultadmin

   # Clear logs
   sudo rm -rf /var/log/*.log
   sudo rm -rf /tmp/*

   # Clear bash history
   cat /dev/null > ~/.bash_history
   history -c
   ```

2. **Create Image Manifest**
   ```json
   {
     "name": "vault-cube-demo-box",
     "version": "1.0.0",
     "build_date": "2025-11-15T10:30:00Z",
     "os": "Ubuntu 24.04 LTS",
     "kernel": "6.8.0-45-generic",
     "nvidia_driver": "550.127.05",
     "cuda_version": "12.4.0",
     "frameworks": {
       "pytorch": "2.1.0+cu124",
       "tensorflow": "2.14.0",
       "vllm": "0.2.1"
     },
     "checksum_sha256": "abc123...",
     "size_bytes": 53687091200
   }
   ```

3. **Generate Checksum**
   ```bash
   sha256sum vault-cube-demo-box-v1.0.qcow2 > vault-cube-demo-box-v1.0.sha256
   ```

4. **Compress Image** (optional)
   ```bash
   qemu-img convert -c -O qcow2 vault-cube-demo-box-v1.0.qcow2 vault-cube-demo-box-v1.0-compressed.qcow2
   ```

### Output Artifacts

```
output-qemu/
├── vault-cube-demo-box-v1.0.qcow2          # Golden image
├── vault-cube-demo-box-v1.0.sha256         # Checksum
├── manifest.json                            # Build manifest
└── packer-build.log                         # Build logs
```

### Validation Gate

**Pass Criteria:**
- Image file created and valid
- Checksum generated
- Manifest complete
- Image boots successfully in test VM

**On Failure:**
- Check Packer post-processors
- Verify image file integrity
- Retry finalization

### Time Estimate
- **Cleanup:** 1 minute
- **Manifest generation:** 30 seconds
- **Checksum:** 1 minute
- **Total:** ~3 minutes

---

## Complete Pipeline Timeline

| Stage | Activity | Duration | Cached Duration |
|-------|----------|----------|-----------------|
| **Stage 1** | Source & Pre-Build | 2 min | 2 min |
| **Stage 2** | Packer Build | 15 min | 10 min |
| **Stage 3** | Ansible Provisioning | 17 min | 17 min |
| **Stage 4** | Testing & Validation | 30 min | 30 min |
| **Stage 5** | Image Finalization | 3 min | 3 min |
| **TOTAL** | **End-to-End** | **67 min** | **62 min** |

**Note:** Target is <30 min for Packer+Ansible (Stages 2-3), which we achieve at 27 min cached.

---

## Caching & Optimization

### Package Caching (apt-cacher-ng)

**Setup:**
```yaml
# ansible/roles/common/tasks/main.yml
- name: Install apt-cacher-ng
  apt:
    name: apt-cacher-ng
    state: present

- name: Configure APT to use cache
  copy:
    content: 'Acquire::http::Proxy "http://localhost:3142";'
    dest: /etc/apt/apt.conf.d/00proxy
```

**Benefit:** ~50% faster package downloads on subsequent builds

### ISO Caching (Packer)

**Configuration:**
```hcl
source "qemu" "ubuntu-2404" {
  iso_url      = "https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso"
  iso_checksum = "sha256:..."

  # Packer caches ISO automatically in packer_cache/
}
```

**Benefit:** Skip 2-minute ISO download after first build

### Ansible Fact Caching

**Configuration:**
```ini
# ansible/ansible.cfg
[defaults]
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_cache
fact_caching_timeout = 86400  # 24 hours
```

**Benefit:** ~20% faster Ansible runs

### Docker Image Pre-Pulling

**Strategy:** Pre-pull common GPU images during Layer 3

```yaml
# ansible/roles/nvidia-container-toolkit/tasks/main.yml
- name: Pre-pull GPU test images
  docker_image:
    name: "{{ item }}"
    source: pull
  loop:
    - nvidia/cuda:12.4.0-base-ubuntu24.04
    - pytorch/pytorch:2.1.0-cuda12.1-cudnn8-runtime
```

**Benefit:** Faster test execution in Stage 4

---

## Error Handling & Recovery

### Build Failures

**Packer Build Fails:**
```bash
# Debug mode for detailed logs
packer build -debug ubuntu-24.04-demo-box.pkr.hcl

# Check VM console output
# Fix cloud-init configuration
# Retry build
```

**Ansible Task Fails:**
```bash
# Verbose output
ansible-playbook site.yml -vvv

# Run specific layer
ansible-playbook site.yml --tags layer2

# Resume from failed task
ansible-playbook site.yml --start-at-task="Install NVIDIA driver"
```

### Test Failures

**GPU Detection Fails:**
- Check `nvidia-smi`
- Verify driver installation
- Check dmesg for GPU errors
- Rollback to Layer 1, retry Layer 2

**Performance Tests Fail:**
- Check GPU utilization
- Verify CUDA version compatibility
- Review framework versions
- Re-run tests in isolation

---

## CI/CD Integration (Future - Epic 1B)

### GitHub Actions Workflow (Draft)

```yaml
name: Build Golden Image

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Validate Packer template
        run: packer validate packer/ubuntu-24.04-demo-box.pkr.hcl
      - name: Lint Ansible playbooks
        run: ansible-lint ansible/playbooks/site.yml

  build:
    needs: validate
    runs-on: self-hosted  # GPU-enabled runner
    steps:
      - uses: actions/checkout@v3
      - name: Build golden image
        run: packer build packer/ubuntu-24.04-demo-box.pkr.hcl
      - name: Run tests
        run: bash scripts/run-all-tests.sh
      - name: Upload artifact
        uses: actions/upload-artifact@v3
        with:
          name: golden-image-v${{ github.run_number }}
          path: output-qemu/*.qcow2
```

**Note:** Deferred to Epic 1B, manual builds for Epic 1A

---

**Document Version:** 1.0
**Last Updated:** 2025-10-29
**Next Review:** After Week 1 implementation
