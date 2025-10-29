# Epic 1A: Optimization Opportunities

**Date:** 2025-10-29
**Optimizer:** Vault AI Golden Image Architect
**Version:** 1.0
**Epic:** 1A - Demo Box Operation

---

## Executive Summary

This document identifies **12 optimization opportunities** to accelerate Epic 1A delivery, improve build efficiency, and reduce timeline risk. These optimizations focus on **parallel execution, build caching, and automation**.

**Optimization Impact:**
- ⚡ **Build Time:** Reduce from 30+ min → **<15 min** (50% faster)
- 🔄 **Iteration Speed:** Enable rapid testing (rebuild in <5 min for minor changes)
- 👥 **Parallel Work:** Enable 2-3 engineers working simultaneously
- 🤖 **Automation:** Reduce manual steps by 70%

**Estimated Time Savings:** 12-18 hours over Epic 1A lifecycle (20% efficiency gain)

---

## Critical Optimizations (High ROI)

### OPT-1: Multi-Stage Packer Builds
**Impact:** ⚡⚡⚡ **VERY HIGH** (50% build time reduction)
**Effort:** 4 hours
**Timeline Savings:** 12+ hours (across multiple builds)

#### Current State
```yaml
current_architecture:
  single_build:
    - Install Ubuntu 24.04 (10 min)
    - Install drivers + CUDA (8 min)
    - Install frameworks (PyTorch, TensorFlow, vLLM) (12 min)
    - Total: ~30 minutes per build

  problem:
    - Any change requires full rebuild (30 min)
    - Week 2-3 iteration cycles waste time
    - Can't rollback to intermediate stages
```

#### Optimized Architecture
```yaml
multi_stage_builds:
  stage_1_base:
    name: vault-cube-base.qcow2
    contents:
      - Ubuntu 24.04 LTS
      - System packages
      - Docker + containerd
      - Python environment
    build_time: 10 minutes
    frequency: Rarely changes

  stage_2_drivers:
    name: vault-cube-drivers.qcow2
    base: vault-cube-base.qcow2
    contents:
      - NVIDIA driver 550+
      - CUDA 12.4
      - cuDNN 9.x
      - NVIDIA Container Toolkit
    build_time: 8 minutes (only if driver changes)
    frequency: Weekly (driver updates)

  stage_3_frameworks:
    name: vault-cube-frameworks.qcow2
    base: vault-cube-drivers.qcow2
    contents:
      - PyTorch 2.x
      - TensorFlow 2.x
      - vLLM
      - Cached models
    build_time: 12 minutes (only if frameworks change)
    frequency: Daily (testing)

  stage_4_final:
    name: vault-cube-v1.0.0-demo.qcow2
    base: vault-cube-frameworks.qcow2
    contents:
      - Configuration tweaks
      - Monitoring scripts
      - Documentation
    build_time: 2 minutes
    frequency: Every commit

iteration_scenarios:
  change_monitoring_script:
    current: "30 min (full rebuild)"
    optimized: "2 min (rebuild Stage 4 only)"
    savings: "28 minutes"

  change_pytorch_version:
    current: "30 min (full rebuild)"
    optimized: "14 min (rebuild Stage 3-4)"
    savings: "16 minutes"

  change_nvidia_driver:
    current: "30 min (full rebuild)"
    optimized: "22 min (rebuild Stage 2-4)"
    savings: "8 minutes"
```

#### Implementation
```hcl
# packer/stage-1-base.pkr.hcl
source "qemu" "ubuntu-base" {
  iso_url      = "https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso"
  iso_checksum = "sha256:..."
  vm_name      = "vault-cube-base.qcow2"
  disk_size    = "50G"
  # ... base configuration
}

build {
  sources = ["source.qemu.ubuntu-base"]
  provisioner "ansible" {
    playbook_file = "ansible/playbooks/base-system.yml"
  }
}

# packer/stage-2-drivers.pkr.hcl
source "qemu" "drivers" {
  disk_image       = true
  iso_url          = "vault-cube-base.qcow2"  # Build on top of Stage 1
  iso_checksum     = "none"
  vm_name          = "vault-cube-drivers.qcow2"
  use_backing_file = true  # QCOW2 backing file (saves space)
}

build {
  sources = ["source.qemu.drivers"]
  provisioner "ansible" {
    playbook_file = "ansible/playbooks/nvidia-stack.yml"
  }
}

# Similar for Stage 3 and 4...
```

**Benefits:**
- **50% faster iteration** (change monitoring script: 2 min vs 30 min)
- **Rollback capability** (revert to any stage)
- **Disk space efficient** (QCOW2 backing files share unchanged data)
- **Parallel development** (frontend dev works on Stage 4 while backend dev works on Stage 3)

**Timeline Impact:** -12 hours (Week 2-3 iteration time saved)

---

### OPT-2: APT Package Caching (apt-cacher-ng)
**Impact:** ⚡⚡ **HIGH** (30% package install reduction)
**Effort:** 1 hour
**Timeline Savings:** 3-5 hours (across builds)

#### Problem
Every Packer build downloads packages from Ubuntu repositories:
- NVIDIA CUDA packages: ~2GB
- PyTorch dependencies: ~1.5GB
- System packages: ~500MB
- **Total:** 4GB download per build @ 100 Mbps = **5 minutes**

With 10-15 builds during Epic 1A: **50-75 minutes wasted downloading**

#### Solution
```yaml
apt_cacher_ng_setup:
  install_on: "Build machine (MacBook or Linux workstation)"

  installation:
    - sudo apt-get install apt-cacher-ng
    - Service runs on port 3142

  configure_packer:
    # In Packer preseed/cloud-init
    d-i mirror/http/proxy string http://BUILD_MACHINE_IP:3142

  configure_ansible:
    # In Ansible playbook
    - name: Configure APT proxy
      copy:
        dest: /etc/apt/apt.conf.d/00proxy
        content: |
          Acquire::http::Proxy "http://BUILD_MACHINE_IP:3142";

benefits:
  first_build: "5 min download (cache miss)"
  subsequent_builds: "30 sec download (cache hit)"
  savings_per_build: "4.5 minutes"
  total_savings_10_builds: "45 minutes"
```

**Timeline Impact:** -45 minutes (Week 2-3)

---

### OPT-3: PyPI Package Caching (devpi or PyPI mirror)
**Impact:** ⚡⚡ **HIGH** (40% Python package install reduction)
**Effort:** 2 hours
**Timeline Savings:** 4-6 hours

#### Problem
PyTorch, TensorFlow, vLLM downloads:
- PyTorch CUDA 12.4 wheel: ~2.5GB
- TensorFlow: ~500MB
- vLLM + dependencies: ~800MB
- **Total:** 3.8GB @ 100 Mbps = **5 minutes per build**

#### Solution
```yaml
pypi_caching:
  option_a_devpi:
    install: "pip install devpi-server devpi-web"
    run: "devpi-server --start --host 0.0.0.0 --port 3141"
    configure_pip:
      - PIP_INDEX_URL=http://BUILD_MACHINE_IP:3141/root/pypi/+simple/
    benefits: "Full PyPI mirror with caching"

  option_b_local_wheels:
    download_once:
      - pip download torch --index-url https://download.pytorch.org/whl/cu124
      - pip download tensorflow[and-cuda]
      - pip download vllm
    ansible_copy:
      - Copy wheels to /tmp/wheels/ in Packer build
      - pip install --no-index --find-links /tmp/wheels/ torch
    benefits: "Simple, no server needed"

  recommended: "Option B (simpler for Epic 1A)"

  savings:
    first_build: "5 min (download wheels)"
    subsequent_builds: "1 min (install from cache)"
    savings_per_build: "4 minutes"
```

**Timeline Impact:** -40 minutes (Week 2-3)

---

### OPT-4: Parallel Ansible Task Execution
**Impact:** ⚡ **MEDIUM** (15% faster playbook execution)
**Effort:** 1 hour
**Timeline Savings:** 2-3 hours

#### Problem
Ansible executes tasks sequentially by default. Some tasks can run in parallel:
- Downloading models (4 models can download simultaneously)
- Installing independent packages

#### Solution
```yaml
ansible_optimization:
  async_tasks:
    - name: Download models in parallel
      command: huggingface-cli download {{ item }}
      loop:
        - facebook/opt-125m
        - meta-llama/Llama-2-7b-hf
        - gpt2
        - bert-base-uncased
      async: 600  # 10 minutes timeout
      poll: 0     # Don't wait, fire and forget

    - name: Wait for model downloads
      async_status:
        jid: "{{ item.ansible_job_id }}"
      register: download_jobs
      until: download_jobs.finished
      retries: 60

  package_installation:
    - Use with_items for package lists
    - Ansible installs multiple packages in single apt transaction

  savings:
    model_downloads: "Sequential: 8 min → Parallel: 3 min (5 min saved)"
    package_installs: "Sequential: 4 min → Batched: 2 min (2 min saved)"
```

**Timeline Impact:** -2.5 hours (across builds)

---

### OPT-5: Enable Packer Parallel Builds
**Impact:** ⚡⚡⚡ **VERY HIGH** (if multiple build targets)
**Effort:** 30 minutes
**Timeline Savings:** Variable (if building multiple variants)

#### Use Case
If building multiple image variants (demo vs production), Packer can build them in parallel.

#### Configuration
```hcl
# packer/ubuntu-24.04.pkr.hcl
build {
  sources = [
    "source.qemu.demo-box",
    "source.qemu.production-box"
  ]

  # Packer builds both variants in parallel (if system has resources)
}

# Run with max parallelism
packer build -parallel-builds=2 ubuntu-24.04.pkr.hcl
```

**Timeline Impact:** -50% (if building 2 variants)

**Note:** Not applicable for Epic 1A (single variant), but useful for Epic 1B.

---

## Medium Priority Optimizations

### OPT-6: Pre-Downloaded ISO and Packages
**Impact:** ⚡ **MEDIUM**
**Effort:** 30 minutes
**Savings:** 1-2 hours

```yaml
pre_download:
  ubuntu_iso:
    - Download once: ubuntu-24.04-live-server-amd64.iso (2.5GB)
    - Store in local cache: ~/.packer.d/isos/
    - Packer uses local ISO (saves 5 min per build)

  nvidia_packages:
    - Download CUDA .deb packages offline
    - Host on local web server or file share
    - Ansible installs from local source
```

---

### OPT-7: Reduce VM Resource Allocation During Builds
**Impact:** ⚡ **MEDIUM**
**Effort:** 15 minutes
**Savings:** Enables parallel work

#### Current Problem
Packer VM uses 8GB RAM, 4 cores. On MacBook (16GB RAM), this blocks other work.

#### Optimization
```hcl
source "qemu" "ubuntu-2404" {
  memory = 4096  # 4GB instead of 8GB (sufficient for build)
  cpus   = 2     # 2 cores instead of 4 (still fast enough)

  # Build time impact: +2 minutes
  # Benefit: Can run other tasks in parallel (IDE, browser, tests)
}
```

**Benefit:** Enables developer to work on documentation while build runs.

---

### OPT-8: Ansible Fact Caching
**Impact:** ⚡ **LOW-MEDIUM**
**Effort:** 30 minutes
**Savings:** 30 seconds per playbook run

```yaml
ansible_fact_caching:
  enable: true
  cache_location: /tmp/ansible_facts
  timeout: 3600

  # In ansible.cfg
  [defaults]
  gathering = smart
  fact_caching = jsonfile
  fact_caching_connection = /tmp/ansible_facts
  fact_caching_timeout = 3600

  benefit:
    - First run: Gather facts (10 sec)
    - Subsequent runs: Use cached facts (1 sec)
    - Savings: 9 seconds per run (minor but free)
```

---

### OPT-9: Compress Golden Image with QCOW2
**Impact:** 💾 **STORAGE** (70% disk space reduction)
**Effort:** 5 minutes
**Savings:** Disk space, transfer time

```bash
# After Packer build
qemu-img convert -O qcow2 -c \
  vault-cube-demo-box-raw.img \
  vault-cube-demo-box-v1.0.0.qcow2

# Result
# Raw: 50GB → QCOW2 compressed: 15GB
# Transfer time: 100Mbps network = 70 min → 20 min (50 min saved)
```

---

### OPT-10: Implement Build Checksums for Cache Invalidation
**Impact:** ⚡ **MEDIUM** (prevents unnecessary rebuilds)
**Effort:** 2 hours
**Savings:** 3-5 hours (avoid rebuilding when nothing changed)

```bash
# Generate checksum of source files
find ansible/ packer/ -type f -exec sha256sum {} \; | sort | sha256sum > .build-checksum

# Before building, compare checksums
if diff .build-checksum .last-build-checksum; then
  echo "No changes detected, skipping build"
  exit 0
fi

# After successful build
cp .build-checksum .last-build-checksum
```

---

## Low Priority Optimizations (Epic 1B)

### OPT-11: Incremental Ansible Playbook Execution
**Impact:** ⚡ **LOW**
**Effort:** 3 hours
**Savings:** 5-10 minutes per test

Use Ansible tags to run only changed roles:
```bash
# Only run nvidia role
ansible-playbook site.yml --tags nvidia

# Skip slow roles
ansible-playbook site.yml --skip-tags "model-download,stress-test"
```

---

### OPT-12: CI/CD Pipeline with Build Caching
**Impact:** ⚡⚡ **HIGH** (long-term)
**Effort:** 6 hours
**Savings:** Enables continuous delivery

**Defer to Epic 1B** (infrastructure investment)

---

## Optimization Implementation Plan

### Week 1 (Foundation - MacBook Work)
- ✅ **OPT-1:** Multi-stage Packer builds (+4 hours, -12 hours savings)
- ✅ **OPT-2:** APT caching (+1 hour, -45 min savings)
- ✅ **OPT-3:** PyPI caching (+2 hours, -40 min savings)
- ✅ **OPT-6:** Pre-download ISO (+30 min, -1 hour savings)

**Net:** +7.5 hours investment, -14.5 hours savings = **+7 hours saved**

### Week 2 (AI Runtime - GPU Work)
- ✅ **OPT-4:** Parallel Ansible tasks (+1 hour, -2.5 hours savings)
- ✅ **OPT-7:** Reduce VM resources (+15 min, enables parallel work)
- ✅ **OPT-9:** QCOW2 compression (+5 min, saves transfer time)

**Net:** +1.3 hours investment, -3+ hours savings = **+1.7 hours saved**

### Week 3 (Validation)
- ✅ **OPT-10:** Build checksums (+2 hours, -3 hours savings)

**Net:** +2 hours investment, -3 hours savings = **+1 hour saved**

### Total Optimization ROI
- **Investment:** 10.8 hours (setup time)
- **Savings:** 20.5 hours (across Epic 1A)
- **Net Benefit:** **+9.7 hours saved** (15% efficiency gain)

---

## Recommended Optimization Priority

### Must Implement (High ROI)
1. ✅ **OPT-1:** Multi-stage builds (50% iteration speed improvement)
2. ✅ **OPT-2:** APT caching (45 min saved across builds)
3. ✅ **OPT-3:** PyPI caching (40 min saved)

### Should Implement (Good ROI)
4. ✅ **OPT-4:** Parallel Ansible tasks (2.5 hours saved)
5. ✅ **OPT-6:** Pre-download ISO (1 hour saved)

### Optional (Nice to Have)
6. ⏸️ **OPT-7:** Reduce VM resources (enables parallel work)
7. ⏸️ **OPT-9:** QCOW2 compression (storage savings)
8. ⏸️ **OPT-10:** Build checksums (prevents unnecessary rebuilds)

### Defer to Epic 1B
9. ⏸️ **OPT-11:** Ansible tags (minor benefit, adds complexity)
10. ⏸️ **OPT-12:** CI/CD pipeline (large investment, long-term benefit)

---

## Conclusion

**Key Takeaway:** Invest **11 hours in Week 1 optimizations** to save **20+ hours in Weeks 2-3**.

**Critical Optimizations:**
- Multi-stage Packer builds (biggest impact)
- Package caching (APT + PyPI)
- Parallel Ansible execution

**Expected Result:**
- Build time: 30 min → **15 min** (50% faster)
- Iteration speed: 30 min → **2-5 min** (85-93% faster)
- Total time savings: **20+ hours** (enables 3-week timeline with buffer)

**Recommendation:** ✅ **Implement OPT-1 through OPT-6 in Week 1**

---

**Document Owner:** Vault AI Architect
**Status:** Complete
**Next Steps:** Prioritize optimizations with DevOps lead, implement in Week 1
