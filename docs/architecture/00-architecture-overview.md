# Epic 1A Implementation Architecture Overview

**Version:** 1.0
**Date:** 2025-10-29
**Status:** Active Design
**Architect:** System Architecture Designer

---

## Executive Summary

This document defines the implementation architecture for Epic 1A: Demo Box Operation. The architecture balances **simplicity** (functional demo box) with **extensibility** (foundation for Epic 1B production hardening).

### Key Architectural Principles

1. **Layered Design** - 5 distinct layers with clear interfaces
2. **Idempotency** - All provisioning steps can be re-run safely
3. **Testability** - Each layer independently validated
4. **Incrementality** - Build complexity progressively
5. **Documentation-First** - Architecture decisions recorded in memory

---

## System Context

### Purpose
Build an automated golden image pipeline that delivers a **functional AI workstation** demonstrating 4× RTX 5090 GPU capability for PyTorch, TensorFlow, and vLLM workloads.

### Constraints
- **Time:** 2-3 weeks (60-90 hours)
- **Hardware:** 4× RTX 5090 GPUs (Week 2+)
- **Scope:** Demo box only (defer full production hardening to Epic 1B)
- **Development:** 70% MacBook-friendly, 30% GPU-dependent

### Key Stakeholders
- **Customer Success:** Demo box for customer validation
- **Engineering:** Foundation for production image (Epic 1B)
- **DevOps:** Automated build pipeline
- **Security:** Basic hardening compliance

---

## Architectural Layers (Bottom-Up)

```
┌─────────────────────────────────────────────────────────┐
│ Layer 5: Validation & Monitoring                       │
│ - GPU detection tests                                   │
│ - PyTorch DDP validation                               │
│ - vLLM inference tests                                 │
│ - 24-hour stress testing                               │
│ - htop/nvtop monitoring                                │
└─────────────────────────────────────────────────────────┘
                          ▲
┌─────────────────────────────────────────────────────────┐
│ Layer 4: AI Frameworks (GPU-Dependent)                 │
│ - PyTorch 2.x + CUDA 12.4                              │
│ - TensorFlow 2.x + CUDA 12.4                           │
│ - vLLM (LLM inference engine)                          │
│ - Python 3.10+ environment                             │
└─────────────────────────────────────────────────────────┘
                          ▲
┌─────────────────────────────────────────────────────────┐
│ Layer 3: GPU Runtime (GPU-Dependent)                   │
│ - NVIDIA Container Toolkit                             │
│ - Docker Engine (nvidia runtime)                       │
│ - containerd with GPU support                          │
└─────────────────────────────────────────────────────────┘
                          ▲
┌─────────────────────────────────────────────────────────┐
│ Layer 2: Driver Stack (GPU-Dependent)                  │
│ - NVIDIA Driver 550.127.05+                            │
│ - CUDA Toolkit 12.4.0+                                 │
│ - cuDNN 9.0.0+                                         │
│ - Kernel module loading                                │
└─────────────────────────────────────────────────────────┘
                          ▲
┌─────────────────────────────────────────────────────────┐
│ Layer 1: Base System (MacBook-Friendly)                │
│ - Ubuntu 24.04 LTS                                     │
│ - Basic security hardening (SSH, UFW, fail2ban)        │
│ - Docker Engine (CPU-only initially)                   │
│ - Python 3.10+ environment                             │
│ - Networking & user configuration                      │
└─────────────────────────────────────────────────────────┘
```

### Layer Dependencies

- **Layer 1 → 2:** Base system provides kernel for driver loading
- **Layer 2 → 3:** Drivers enable GPU runtime
- **Layer 3 → 4:** GPU runtime enables framework GPU acceleration
- **Layer 4 → 5:** Frameworks provide validation targets

### Rollback Strategy

Each layer is independently testable. If Layer N fails:
1. Validate Layer N-1 is still functional
2. Document Layer N failure
3. Rollback to last known-good state
4. Debug Layer N in isolation

---

## Build Pipeline Architecture

### High-Level Pipeline

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│  Source  │────▶│  Packer  │────▶│  Ansible │────▶│   Test   │
│   Code   │     │  Build   │     │Provision │     │Validate  │
└──────────┘     └──────────┘     └──────────┘     └──────────┘
                       │                │                │
                       ▼                ▼                ▼
                 ┌──────────┐     ┌──────────┐     ┌──────────┐
                 │   Base   │     │Configured│     │ Validated│
                 │  Image   │     │  Image   │     │  Golden  │
                 │ (.qcow2) │     │ (Layers  │     │  Image   │
                 └──────────┘     │ 1-5 Done)│     │ (v1.0)   │
                                  └──────────┘     └──────────┘
```

### Detailed Build Stages

#### Stage 1: Packer Build (15-20 minutes)
```
Input:  Ubuntu 24.04 LTS ISO
Action: Automated installation via cloud-init
Output: Base Ubuntu image (Layer 1 started)
```

**Key Activities:**
- Download Ubuntu ISO (cached)
- Preseed/cloud-init configuration
- Initial user setup (vaultadmin)
- SSH key injection
- Base image creation

**Validation Gate:**
- SSH access works
- Image boots successfully
- Disk partitioning correct

#### Stage 2: Ansible Provisioning (10-15 minutes)
```
Input:  Base image from Stage 1
Action: Layer-by-layer provisioning
Output: Fully configured image (Layers 1-4)
```

**Provisioning Phases:**

**Phase 1: Base System (Layer 1) - 3 minutes**
- System updates (`apt update && apt upgrade`)
- Package installation (build-essential, git, curl, etc.)
- User configuration (sudo, groups)
- Timezone/locale settings
- Basic security (SSH hardening, UFW firewall)
- Docker installation (CPU-only initially)

**Phase 2: Driver Stack (Layer 2) - 4 minutes** [GPU REQUIRED]
- NVIDIA repository setup
- NVIDIA driver 550+ installation
- CUDA toolkit 12.4+ installation
- cuDNN 9.x installation
- Kernel module configuration
- System reboot

**Phase 3: GPU Runtime (Layer 3) - 2 minutes** [GPU REQUIRED]
- NVIDIA Container Toolkit installation
- Docker daemon reconfiguration (nvidia runtime)
- Docker service restart
- GPU container test

**Phase 4: AI Frameworks (Layer 4) - 6 minutes** [GPU REQUIRED]
- Python environment setup (if not done in Layer 1)
- PyTorch 2.x installation (CUDA 12.4 build)
- TensorFlow 2.x installation (CUDA 12.4 build)
- vLLM installation
- Framework validation

**Validation Gates (Per Phase):**
- Phase 1: `ansible-playbook site.yml --check` passes
- Phase 2: `nvidia-smi` shows 4 GPUs
- Phase 3: `docker run --gpus all nvidia/cuda:12.4.0-base nvidia-smi` works
- Phase 4: PyTorch/TensorFlow can import and detect GPUs

#### Stage 3: Testing & Validation (20-30 minutes)
```
Input:  Provisioned image from Stage 2
Action: Comprehensive testing (Layer 5)
Output: Validated golden image
```

**Test Suites:**

1. **GPU Detection Test** (2 minutes)
   - All 4 GPUs visible
   - Correct GPU memory reported
   - PCIe link speed verified
   - Idle temperatures <60°C

2. **PyTorch Multi-GPU Test** (10 minutes)
   - DistributedDataParallel (DDP) test
   - ResNet-50 training on 4 GPUs
   - Scaling efficiency >80%
   - GPU utilization >90%

3. **TensorFlow GPU Test** (5 minutes)
   - Multi-GPU tensor operations
   - GPU device listing
   - Memory allocation test

4. **vLLM Inference Test** (10 minutes)
   - Load Llama-2-7B or opt-1.3b
   - Inference throughput test
   - GPU memory usage validation
   - Output quality check

5. **Docker GPU Test** (3 minutes)
   - Container GPU access validation
   - Multi-container GPU sharing

**Pass Criteria:**
- All tests pass without errors
- Performance targets met
- No system errors in logs

---

## Technology Stack Decisions

### Decision 1: Packer Builder - QEMU vs VirtualBox vs Bare Metal

**Decision:** Use **QEMU** builder for initial development, transition to **bare metal** for final build.

**Rationale:**

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| **QEMU** | ✅ MacBook-friendly (hvf accelerator)<br>✅ Fast iteration<br>✅ Cross-platform | ❌ GPU passthrough complex<br>❌ Not final target | ✅ **Use for Layer 1 development** |
| **VirtualBox** | ✅ MacBook-friendly<br>✅ Good documentation | ❌ No GPU passthrough<br>❌ Slower than QEMU | ❌ Skip (QEMU better) |
| **Bare Metal** | ✅ Real GPU access<br>✅ Accurate performance | ❌ Slower iteration<br>❌ Requires hardware | ✅ **Use for Layers 2-5** |

**Implementation:**
- **Week 1:** Develop Layer 1 with QEMU on MacBook
- **Week 2-3:** Build Layers 2-5 on bare metal GPU hardware
- **Final:** Build entire image on bare metal for consistency

**Stored in Memory:** `epic1a/decisions/technical/packer-builder`

---

### Decision 2: Ansible Execution - Local vs Remote

**Decision:** Use **local execution** (Packer Ansible provisioner in local mode).

**Rationale:**

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| **Local** | ✅ Simpler (no SSH during build)<br>✅ Faster (no network overhead)<br>✅ Works in chroot | ❌ Requires Ansible on build machine | ✅ **Selected** |
| **Remote** | ✅ Ansible can be anywhere | ❌ Requires SSH setup during Packer build<br>❌ Network dependency | ❌ Rejected |

**Implementation:**
```hcl
provisioner "ansible" {
  playbook_file = "../ansible/playbooks/site.yml"
  use_proxy     = false
  ansible_env_vars = [
    "ANSIBLE_HOST_KEY_CHECKING=False"
  ]
}
```

**Stored in Memory:** `epic1a/decisions/technical/ansible-execution`

---

### Decision 3: Docker Runtime - containerd vs docker.io

**Decision:** Use **Docker Engine (docker.io)** with **containerd** as runtime.

**Rationale:**

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| **Docker Engine** | ✅ Familiar tooling (docker CLI)<br>✅ Better documentation<br>✅ Easier NVIDIA integration | ❌ Additional daemon overhead | ✅ **Selected** |
| **containerd only** | ✅ Lighter weight<br>✅ Kubernetes-native | ❌ Less user-friendly<br>❌ More complex NVIDIA setup | ❌ Deferred to Epic 1B |

**NVIDIA Integration:**
- Docker Engine + NVIDIA Container Toolkit = well-documented
- containerd + nvidia runtime = more complex, better for K8s

**Stored in Memory:** `epic1a/decisions/technical/docker-runtime`

---

### Decision 4: Python Environment - System Python vs venv vs conda

**Decision:** Use **system Python 3.12** (Ubuntu 24.04 default) with **pip** for framework installation.

**Rationale:**

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| **System Python** | ✅ Simplest setup<br>✅ No environment management<br>✅ Fast installation | ❌ Single environment<br>❌ Potential conflicts | ✅ **Selected for demo box** |
| **venv** | ✅ Isolated environments<br>✅ Standard library | ❌ Requires activation<br>❌ Path management | ⏸️ Consider for Epic 1B |
| **conda** | ✅ Best for ML workflows<br>✅ Package management | ❌ Large install size<br>❌ Complexity | ❌ Overkill for demo |

**Note:** For demo box simplicity, system Python is sufficient. Epic 1B may introduce venv for multi-user scenarios.

**Stored in Memory:** `epic1a/decisions/technical/python-environment`

---

### Decision 5: Monitoring - Basic vs Comprehensive

**Decision:** Use **basic monitoring** (htop, iotop, nvtop) for Epic 1A.

**Rationale:**

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| **Basic (htop/nvtop)** | ✅ Lightweight<br>✅ No infrastructure overhead<br>✅ Sufficient for demos | ❌ No historical data<br>❌ No alerting | ✅ **Selected for Epic 1A** |
| **Prometheus + Grafana** | ✅ Production-grade<br>✅ Historical metrics<br>✅ Dashboards | ❌ Complex setup<br>❌ Resource overhead | ⏸️ **Deferred to Epic 1B** |

**Epic 1A Monitoring Stack:**
- `htop` - CPU/RAM monitoring (TUI)
- `iotop` - Disk I/O monitoring (TUI)
- `nvtop` - GPU monitoring (TUI, beautiful)
- `nvidia-smi` - GPU status (CLI)
- Simple monitoring script: `scripts/monitor.sh`

**Stored in Memory:** `epic1a/decisions/technical/monitoring-approach`

---

## Security Architecture (Basic Hardening)

### Scope: Epic 1A (Demo Box)

Epic 1A implements **basic security hardening** only. Full CIS Level 1 compliance is deferred to Epic 1B.

### SSH Hardening

```yaml
# /etc/ssh/sshd_config
PermitRootLogin: no
PasswordAuthentication: no
PubkeyAuthentication: yes
Port: 22  # Keep default for demo box
AllowUsers: vaultadmin
```

**Rationale:** Key-based authentication only, no root login. Port 22 kept for simplicity (Epic 1B may change).

### Firewall Configuration (UFW)

```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp      # SSH
ufw allow 3000/tcp    # Grafana (future)
ufw enable
```

**Rationale:** Restrictive by default, only necessary ports open.

### User Permissions

```yaml
Primary User: vaultadmin
Groups: sudo, docker
Capabilities:
  - Run Docker without sudo
  - Access all GPUs
  - Modify system configuration (via sudo)
```

### Fail2ban

```yaml
Service: SSH
Ban Time: 10 minutes
Max Retries: 5
```

**Rationale:** Basic brute-force protection for SSH.

### Automatic Security Updates

```yaml
Package: unattended-upgrades
Configuration:
  - Security updates only (automatic)
  - All updates (manual, daily notification)
```

**Rationale:** Security patches applied automatically, feature updates require manual approval.

### Deferred to Epic 1B

- Full CIS Level 1 compliance
- SELinux/AppArmor mandatory access controls
- Full disk encryption (LUKS)
- Audit logging (auditd)
- Intrusion detection (AIDE)
- Compliance scanning (OpenSCAP)

**Stored in Memory:** `epic1a/architecture/security`

---

## Testing Architecture

### Testing Pyramid

```
        ┌──────────────┐
        │   Stress     │  ← 24-hour thermal validation
        │   Tests      │     (1 test, long duration)
        └──────────────┘
       ┌────────────────┐
       │  Integration   │  ← Multi-GPU, framework tests
       │     Tests      │     (5-10 tests, medium duration)
       └────────────────┘
      ┌──────────────────┐
      │   Unit Tests     │  ← Ansible role tests, idempotency
      │  (Ansible)       │     (20+ tests, fast)
      └──────────────────┘
```

### Unit Tests (Ansible Roles)

**Tool:** `molecule` (Ansible testing framework)

**Test Cases:**
- Each Ansible role runs idempotently (3× times without errors)
- Package installation verified
- Service states correct (running, enabled)
- Configuration files present and valid

**Example:**
```yaml
# ansible/roles/docker/molecule/default/verify.yml
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
      failed_when: "'20.10' not in docker_version.stdout"
```

**Stored in Memory:** `epic1a/architecture/testing/unit-tests`

---

### Integration Tests (Multi-Layer)

**Test Scenarios:**

1. **GPU Detection Integration** (`scripts/validate-gpus.sh`)
   - Layer 2 (drivers) + Layer 3 (runtime)
   - Validates: All 4 GPUs detected, correct memory, PCIe speed

2. **Docker GPU Integration** (`scripts/test-docker-gpu.sh`)
   - Layer 3 (runtime) + Docker
   - Validates: Container can access GPUs via `--gpus all`

3. **PyTorch Multi-GPU Integration** (`scripts/test-pytorch-ddp.py`)
   - Layer 4 (PyTorch) + Layer 2 (CUDA)
   - Validates: DistributedDataParallel works, scaling >80%

4. **vLLM Inference Integration** (`scripts/test-vllm-inference.py`)
   - Layer 4 (vLLM) + Layer 3 (Docker optional)
   - Validates: LLM inference throughput >10 tokens/sec

5. **Full Stack Integration** (`scripts/test-full-stack.sh`)
   - All layers (1-4)
   - Validates: End-to-end workflow (load model, train, infer)

**Pass Criteria:**
- All integration tests exit with code 0
- Performance targets met
- No errors in system logs (`dmesg`, `/var/log/syslog`)

**Stored in Memory:** `epic1a/architecture/testing/integration-tests`

---

### Validation Tests (Customer-Facing)

**Purpose:** Demonstrate system capability to customers.

**Test Suite:**

1. **GPU Capability Demo** (5 minutes)
   - Run `nvidia-smi` to show 4× RTX 5090 GPUs
   - Display GPU memory, temperature, utilization

2. **PyTorch Training Demo** (10 minutes)
   - Train ResNet-50 on ImageNet-like synthetic data
   - Show 4-GPU scaling vs 1-GPU
   - Display throughput improvement (samples/sec)

3. **vLLM Inference Demo** (10 minutes)
   - Load Llama-2-7B model
   - Interactive prompt/response demonstration
   - Show inference speed (tokens/sec)

4. **Multi-Framework Demo** (5 minutes)
   - Quick PyTorch test
   - Quick TensorFlow test
   - Demonstrate framework coexistence

**Deliverable:** `docs/demo-box-demo-script.md` - Step-by-step demo guide

**Stored in Memory:** `epic1a/architecture/testing/validation-tests`

---

### Performance Tests

**Benchmarks:**

1. **PyTorch DDP Scaling Efficiency**
   - **Target:** >80% scaling efficiency (4 GPUs vs 1 GPU)
   - **Metric:** Throughput (samples/sec)
   - **Workload:** ResNet-50 training, batch size 32

2. **vLLM Inference Throughput**
   - **Target:** >10 tokens/sec (Llama-2-7B, single GPU)
   - **Metric:** Tokens generated per second
   - **Workload:** Batch of 30 prompts, 50 tokens each

3. **GPU Utilization**
   - **Target:** >90% during training
   - **Metric:** GPU utilization percentage
   - **Tool:** `nvidia-smi dmon`

4. **Build Time**
   - **Target:** <30 minutes (Packer + Ansible)
   - **Metric:** End-to-end build duration
   - **Tool:** `time` command

**Stored in Memory:** `epic1a/architecture/testing/performance-benchmarks`

---

### Stress Tests

**24-Hour Thermal Validation**

**Purpose:** Ensure system stability under continuous GPU load without thermal throttling.

**Test Setup:**
```bash
# scripts/stress-test-24hr.sh

# Run on all 4 GPUs in parallel
for gpu in 0 1 2 3; do
  CUDA_VISIBLE_DEVICES=$gpu python -c "
import torch
# Allocate 90% of GPU memory
x = torch.randn(30000, 30000).cuda()
# Continuous matrix operations
while True:
    y = torch.matmul(x, x)
    torch.cuda.synchronize()
" &
done

# Monitor for 24 hours
watch -n 5 nvidia-smi
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

**Fallback:** If thermal issues detected, document and provide mitigation recommendations (improved cooling, fan curves).

**Stored in Memory:** `epic1a/architecture/testing/stress-tests`

---

## Artifact Versioning Strategy

### Version Scheme: Semantic Versioning

**Format:** `vault-cube-demo-box-vMAJOR.MINOR.PATCH.qcow2`

**Examples:**
- `vault-cube-demo-box-v1.0.0.qcow2` - Initial demo box release
- `vault-cube-demo-box-v1.0.1.qcow2` - Bug fix (driver patch)
- `vault-cube-demo-box-v1.1.0.qcow2` - New feature (additional framework)

### Version Components

- **MAJOR:** Breaking changes (OS upgrade, architecture change)
- **MINOR:** New features (additional AI framework, major capability)
- **PATCH:** Bug fixes, security patches, minor updates

### Metadata File

Each image includes `image-manifest.json`:

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
  "size_bytes": 53687091200,
  "packer_version": "1.9.4",
  "ansible_version": "2.15.5"
}
```

**Stored in Memory:** `epic1a/architecture/versioning`

---

## Build Caching Strategy

### Problem
Rebuilding entire image from scratch takes 30+ minutes. Iteration during development is slow.

### Solution: Layer-Based Caching

**Approach:**

1. **Packer Cache:** Cache downloaded ISO and packages
   ```hcl
   # packer/ubuntu-24.04-demo-box.pkr.hcl
   source "qemu" "ubuntu-2404" {
     iso_url      = "https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso"
     iso_checksum = "sha256:..."

     # Cache ISO locally
     output_directory = "output-qemu"

     # Cache intermediate snapshots
     disk_cache = "writeback"
   }
   ```

2. **Ansible Fact Caching:** Speed up Ansible runs
   ```ini
   # ansible/ansible.cfg
   [defaults]
   gathering = smart
   fact_caching = jsonfile
   fact_caching_connection = /tmp/ansible_cache
   fact_caching_timeout = 86400  # 24 hours
   ```

3. **Package Caching:** Use apt-cacher-ng for packages
   ```yaml
   # ansible/roles/common/tasks/main.yml
   - name: Install apt-cacher-ng for package caching
     apt:
       name: apt-cacher-ng
       state: present

   - name: Configure APT to use cache
     copy:
       content: 'Acquire::http::Proxy "http://localhost:3142";'
       dest: /etc/apt/apt.conf.d/00proxy
   ```

4. **Docker Image Caching:** Pre-pull common images
   ```yaml
   # ansible/roles/docker/tasks/main.yml
   - name: Pre-pull GPU test images
     docker_image:
       name: "{{ item }}"
       source: pull
     loop:
       - nvidia/cuda:12.4.0-base-ubuntu24.04
       - pytorch/pytorch:2.1.0-cuda12.1-cudnn8-runtime
   ```

### Expected Speedup

| Build Type | Without Cache | With Cache | Speedup |
|------------|---------------|------------|---------|
| First Build | 30 min | 30 min | 1.0× |
| Rebuild (no changes) | 30 min | 5 min | 6.0× |
| Rebuild (Layer 1 change) | 30 min | 10 min | 3.0× |
| Rebuild (Layer 4 change) | 30 min | 20 min | 1.5× |

**Stored in Memory:** `epic1a/architecture/build-caching`

---

## CI/CD Integration Approach (Future)

### Epic 1A Scope: Manual Builds

For demo box, builds are **manual** (developer-initiated). CI/CD integration deferred to Epic 1B.

### Future CI/CD Design (Epic 1B)

```
Git Push (main)
    │
    ▼
GitHub Actions Trigger
    │
    ├─► Lint Ansible Playbooks (ansible-lint)
    ├─► Validate Packer Templates (packer validate)
    ├─► Security Scan (yamllint, shellcheck)
    │
    ▼
Packer Build (self-hosted runner with GPU)
    │
    ▼
Ansible Provisioning
    │
    ▼
Automated Testing
    │
    ├─► Unit Tests (molecule)
    ├─► Integration Tests
    └─► Smoke Tests
    │
    ▼
Artifact Upload (S3 or GitHub Releases)
    │
    └─► Image versioned and tagged
```

**Requirements for CI/CD:**
- Self-hosted GitHub Actions runner with GPU access
- Sufficient disk space for builds (100GB+)
- Artifact storage (S3, GitHub Releases, or Nexus)
- Notification system (Slack, email)

**Stored in Memory:** `epic1a/architecture/cicd-future`

---

## Rollback & Recovery Strategy

### Rollback Levels

1. **Layer-Level Rollback**
   - If Layer N fails, rollback to Layer N-1
   - Example: NVIDIA driver fails → rollback to base system

2. **Version Rollback**
   - Keep last 3 golden image versions
   - Revert to previous version if new build broken

3. **Configuration Rollback**
   - Git-tracked Ansible playbooks enable version control
   - Revert playbook commits to previous working state

### Recovery Procedures

#### Scenario 1: NVIDIA Driver Fails to Install

**Symptoms:** `nvidia-smi` not found or errors

**Recovery:**
```bash
# 1. Check driver installation logs
sudo journalctl -u nvidia-driver

# 2. Remove broken driver
sudo apt purge nvidia-*
sudo apt autoremove

# 3. Re-run Ansible playbook
ansible-playbook ansible/playbooks/site.yml --tags nvidia-drivers

# 4. Reboot
sudo reboot
```

**Fallback:** Use older driver version (e.g., 545 instead of 550)

#### Scenario 2: Docker GPU Access Not Working

**Symptoms:** `docker run --gpus all` fails

**Recovery:**
```bash
# 1. Verify NVIDIA runtime installed
nvidia-ctk --version

# 2. Check Docker daemon config
cat /etc/docker/daemon.json

# 3. Restart Docker
sudo systemctl restart docker

# 4. Test GPU access
docker run --rm --gpus all nvidia/cuda:12.4.0-base nvidia-smi
```

#### Scenario 3: Framework Installation Fails (PyTorch/TensorFlow)

**Symptoms:** Import errors, CUDA version mismatch

**Recovery:**
```bash
# 1. Uninstall broken framework
pip uninstall torch torchvision torchaudio

# 2. Verify CUDA version
nvcc --version

# 3. Reinstall with correct CUDA version
pip install torch --index-url https://download.pytorch.org/whl/cu124

# 4. Test import
python -c "import torch; print(torch.cuda.is_available())"
```

**Stored in Memory:** `epic1a/architecture/rollback-recovery`

---

## Performance Optimization Strategies

### Build Time Optimization

1. **Parallel Ansible Tasks**
   ```yaml
   # Use async tasks for independent operations
   - name: Install multiple packages in parallel
     apt:
       name: "{{ item }}"
       state: present
     loop: "{{ large_package_list }}"
     async: 600
     poll: 0
     register: apt_install

   - name: Wait for installations to complete
     async_status:
       jid: "{{ item.ansible_job_id }}"
     loop: "{{ apt_install.results }}"
     register: jobs
     until: jobs.finished
     retries: 60
   ```

2. **APT Optimization**
   ```yaml
   # Reduce APT overhead
   - name: Configure APT for speed
     copy:
       content: |
         APT::Acquire::Retries "3";
         APT::Acquire::http::Timeout "10";
         APT::Acquire::ForceIPv4 "true";
       dest: /etc/apt/apt.conf.d/99speedups
   ```

3. **Packer Optimization**
   ```hcl
   # Use faster disk format during build
   source "qemu" "ubuntu-2404" {
     disk_cache = "unsafe"  # Faster, okay for builds
     disk_discard = "unmap"  # Reduce final image size
   }
   ```

### Runtime Performance

1. **GPU P-State Management**
   ```bash
   # Set GPUs to max performance mode (not auto)
   nvidia-smi -pm 1  # Enable persistence mode
   nvidia-smi -pl 450  # Set power limit to max (450W for RTX 5090)
   ```

2. **CPU Governor**
   ```bash
   # Set CPU to performance mode
   cpupower frequency-set -g performance
   ```

3. **Docker Optimizations**
   ```json
   {
     "storage-driver": "overlay2",
     "storage-opts": [
       "overlay2.override_kernel_check=true"
     ],
     "default-shm-size": "8G"  # Larger shared memory for ML workloads
   }
   ```

**Stored in Memory:** `epic1a/architecture/performance-optimization`

---

## Documentation Strategy

### Documentation Deliverables

1. **Architecture Documentation** (this document)
   - System design
   - Layer architecture
   - Technology decisions
   - Testing strategy

2. **Setup Guide** (`docs/demo-box-setup-guide.md`)
   - Step-by-step deployment
   - Hardware requirements
   - Validation checklist
   - Troubleshooting

3. **Ansible Role Documentation**
   - README.md in each role directory
   - Variable documentation
   - Example usage
   - Dependencies

4. **Validation Scripts Documentation**
   - Purpose of each script
   - Expected output
   - Failure scenarios
   - Interpretation guide

5. **Known Issues** (`docs/demo-box-known-issues.md`)
   - RTX 5090 driver quirks
   - Thermal limitations
   - Compatibility issues
   - Workarounds

### Documentation Storage

```
docs/
├── architecture/
│   ├── 00-architecture-overview.md (this file)
│   ├── 01-layer-architecture.md
│   ├── 02-build-pipeline.md
│   ├── 03-testing-strategy.md
│   └── decisions/
│       ├── packer-builder.md
│       ├── ansible-execution.md
│       ├── docker-runtime.md
│       ├── python-environment.md
│       └── monitoring-approach.md
├── demo-box-setup-guide.md
├── demo-box-known-issues.md
└── demo-box-demo-script.md

ansible/
└── roles/
    ├── common/README.md
    ├── docker/README.md
    ├── nvidia/README.md
    └── ...

scripts/
├── README.md  # Overview of all validation scripts
├── validate-gpus.sh
├── test-pytorch-ddp.py
└── ...
```

**Stored in Memory:** `epic1a/architecture/documentation-strategy`

---

## Success Metrics

### Functional Metrics

- [ ] **Build Success Rate:** 100% (builds complete without manual intervention)
- [ ] **GPU Detection Rate:** 100% (all 4 GPUs detected every time)
- [ ] **Test Pass Rate:** 100% (all validation tests pass)
- [ ] **Idempotency:** 100% (Ansible playbooks run 3× without errors)

### Performance Metrics

- [ ] **Build Time:** <30 minutes (Packer + Ansible)
- [ ] **PyTorch Scaling:** >80% efficiency (4 GPUs vs 1 GPU)
- [ ] **vLLM Throughput:** >10 tokens/sec (Llama-2-7B, single GPU)
- [ ] **GPU Utilization:** >90% during training

### Quality Metrics

- [ ] **Documentation Coverage:** 100% (all components documented)
- [ ] **Security Compliance:** Basic hardening complete (SSH, firewall, fail2ban)
- [ ] **Test Coverage:** >80% (automated tests for critical paths)

### Operational Metrics

- [ ] **Deployment Time:** <2 hours (from download to validated)
- [ ] **Recovery Time:** <30 minutes (rollback to previous version)
- [ ] **Uptime:** 24 hours (stress test without failures)

**Stored in Memory:** `epic1a/architecture/success-metrics`

---

## Risks & Mitigations

### Architecture-Specific Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **Layer N breaks Layer N+1** | Medium | High | Independent layer testing, rollback strategy |
| **Caching breaks idempotency** | Low | Medium | Test with and without cache, clear cache on failures |
| **QEMU → Bare Metal differences** | Medium | Low | Validate Layer 1 on both platforms before GPU work |
| **Build time exceeds 30 min** | Medium | Low | Optimize iteratively, parallelize Ansible tasks |

**Stored in Memory:** `epic1a/architecture/risks`

---

## Next Steps

### Immediate Actions

1. **Store architecture decisions in memory:**
   ```bash
   npx claude-flow@alpha memory store epic1a/architecture/overview "$(cat docs/architecture/00-architecture-overview.md)"
   npx claude-flow@alpha memory store epic1a/decisions/technical/packer-builder "QEMU for dev, bare metal for production"
   npx claude-flow@alpha memory store epic1a/decisions/technical/ansible-execution "Local execution via Packer provisioner"
   npx claude-flow@alpha memory store epic1a/decisions/technical/docker-runtime "Docker Engine with containerd"
   npx claude-flow@alpha memory store epic1a/decisions/technical/python-environment "System Python 3.12"
   npx claude-flow@alpha memory store epic1a/decisions/technical/monitoring-approach "Basic (htop/nvtop) for Epic 1A"
   ```

2. **Create detailed layer architecture document** (next document)

3. **Create build pipeline diagram** (visual representation)

4. **Create testing strategy document** (detailed test plans)

5. **Begin Week 1 implementation** (Packer + Ansible for Layer 1)

---

**Document Version:** 1.0
**Last Updated:** 2025-10-29
**Next Review:** End of Week 1 (validate architecture against implementation progress)
