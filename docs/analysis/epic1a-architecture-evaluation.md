# Epic 1A: Architecture Evaluation

**Date:** 2025-10-29
**Evaluator:** Vault AI Golden Image Architect
**Version:** 1.0
**Status:** Comprehensive Analysis Complete

---

## Executive Summary

The Epic 1A implementation plan demonstrates a **well-structured, pragmatic approach** to delivering a functional AI workstation image. The Packer + Ansible automation strategy is sound, the phased approach (Foundation → AI Runtime → Validation) is logical, and the timeline is **realistic but aggressive**.

**Overall Assessment:** ✅ **APPROVED with RECOMMENDED IMPROVEMENTS**

**Key Strengths:**
- Clear separation of MacBook-friendly (Week 1) vs GPU-required (Week 2-3) tasks
- Comprehensive validation strategy with concrete acceptance criteria
- Proper use of industry-standard tools (Packer, Ansible)
- Realistic risk identification (RTX 5090 driver compatibility)

**Key Concerns:**
- RTX 5090 driver availability is a **CRITICAL UNKNOWN** (new hardware, driver maturity uncertain)
- Multi-GPU validation is limited (only DDP test, missing NCCL performance benchmarks)
- Security hardening is minimal (appropriate for Epic 1A, but gaps must be documented)
- Build time optimization opportunities not fully exploited

**Recommendation:** Proceed with Epic 1A as planned, implementing the improvements outlined in this document.

---

## 1. Architecture Analysis

### 1.1 Packer + Ansible Automation Approach

**Rating:** ✅ **EXCELLENT** (9/10)

**Strengths:**
1. **Industry Standard Tooling** - Packer for image building and Ansible for configuration management are battle-tested in enterprise environments
2. **Separation of Concerns** - Packer handles OS installation, Ansible handles configuration (clean architecture)
3. **Idempotency** - Ansible's declarative nature enables repeatable builds
4. **Modularity** - Role-based Ansible structure allows incremental development and testing
5. **Version Control Friendly** - HCL (Packer) and YAML (Ansible) are text-based and git-friendly
6. **MacBook Development** - Week 1 tasks can proceed without GPU hardware (de-risks timeline)

**Weaknesses:**
1. **No CI/CD Integration** - Plan lacks GitHub Actions or GitLab CI pipeline for automated testing
2. **No Image Versioning Strategy** - How will v1.0, v1.1, v2.0 images be managed?
3. **No Rollback Mechanism** - What happens if Week 2 builds break Week 1 functionality?
4. **Limited Build Caching** - No mention of layer caching to speed up iterative builds

**Recommendation:**
```yaml
improvements:
  ci_cd:
    - Add GitHub Actions workflow for Packer validation (syntax check)
    - Add Ansible-lint for playbook quality checks
    - Implement automated testing on PR merges

  versioning:
    - Semantic versioning for images (v1.0.0-demo, v1.1.0-demo)
    - Git tagging strategy aligned with image releases
    - Changelog generation from git commits

  caching:
    - Implement Packer build stages (base → drivers → frameworks)
    - Cache APT packages locally (apt-cacher-ng)
    - Cache PyPI wheels for faster framework installs
```

**Technical Debt:**
- [ ] Add Packer multi-stage builds (cache base OS layer separately)
- [ ] Implement Ansible role dependency management (requirements.yml)
- [ ] Create Makefile for common tasks (make build, make test, make validate)

---

### 1.2 Driver Stack Architecture

**Rating:** ⚠️ **GOOD with CRITICAL RISKS** (7/10)

**Architecture:**
```
┌─────────────────────────────────────┐
│  AI Frameworks (PyTorch, TF, vLLM)  │
├─────────────────────────────────────┤
│  CUDA Toolkit 12.4 + cuDNN 9.x      │
├─────────────────────────────────────┤
│  NVIDIA Container Toolkit            │
├─────────────────────────────────────┤
│  Docker Engine 24.x                  │
├─────────────────────────────────────┤
│  NVIDIA Driver 550.127.05+          │
├─────────────────────────────────────┤
│  Linux Kernel 6.x (Ubuntu 24.04)    │
├─────────────────────────────────────┤
│  Hardware: 4× RTX 5090 GPUs         │
└─────────────────────────────────────┘
```

**Strengths:**
1. **Correct Layering** - Driver → CUDA → Docker → Frameworks is the standard approach
2. **Version Specificity** - CUDA 12.4+ and cuDNN 9.x are correctly matched
3. **Container-First** - Docker + NVIDIA Container Toolkit is enterprise best practice
4. **Multi-GPU Aware** - NCCL 2.21+ mentioned for 4-GPU coordination

**Critical Risks:**

#### RISK 1: RTX 5090 Driver Availability (CRITICAL)
**Impact:** 🔴 **SHOWSTOPPER**
**Probability:** 40% (medium-high)

**Issue:**
- RTX 5090 is **NEW HARDWARE** (likely released Q1 2025)
- NVIDIA driver 550.127.05+ may not exist yet or may be in beta
- Ubuntu 24.04 LTS kernel may require backports for new GPU support
- PCIe 5.0 support in Linux kernel 6.x may have stability issues

**Evidence:**
- RTX 4090 required driver 525+ when launched (6 months of instability)
- New GPU architectures often have driver bugs in first 3-6 months
- Ubuntu LTS kernels are conservative (may need mainline kernel for bleeding-edge hardware)

**Mitigation Strategy:**
```yaml
mitigation_plan:
  pre_epic_validation:
    - Check NVIDIA driver release notes for RTX 5090 support status
    - Verify Ubuntu 24.04 LTS kernel compatibility (may need 6.8+ mainline)
    - Test driver installation in VM (verify package availability)

  fallback_options:
    - Option A: Use RTX 4090 GPUs for Epic 1A (proven stable)
    - Option B: Install Ubuntu 24.10 (newer kernel) instead of 24.04 LTS
    - Option C: Compile NVIDIA driver from source (DKMS)
    - Option D: Wait for NVIDIA driver 560+ beta release

  buffer_allocation:
    - Reserve Week 4 (buffer week) specifically for driver debugging
    - Have secondary GPU available (RTX 4090) for testing
```

**Action Items:**
- [ ] **IMMEDIATE**: Research RTX 5090 Linux driver status (check NVIDIA forums, phoronix)
- [ ] **BEFORE EPIC 1A START**: Confirm driver availability in NVIDIA CUDA repository
- [ ] **WEEK 1**: Test driver package installation in Ubuntu 24.04 VM (without GPU)
- [ ] **CONTINGENCY**: Procure single RTX 4090 as backup GPU ($1,500)

#### RISK 2: CUDA 12.4 Framework Compatibility
**Impact:** 🟡 **MEDIUM**
**Probability:** 30%

**Issue:**
- PyTorch official builds may lag behind CUDA releases (currently CUDA 12.1 stable)
- TensorFlow `tensorflow[and-cuda]` package may not support CUDA 12.4 yet
- vLLM may require specific CUDA versions

**Mitigation:**
```yaml
cuda_compatibility_check:
  pytorch:
    - Check https://pytorch.org/get-started/locally/ for CUDA 12.4 build
    - Fallback: Use CUDA 12.1 (PyTorch 2.x officially supported)
    - Worst case: Build PyTorch from source (adds 2-3 hours)

  tensorflow:
    - Check https://www.tensorflow.org/install/gpu for CUDA 12.4 support
    - Fallback: Use tensorflow-gpu 2.15 with CUDA 12.2
    - Test in virtualenv before Ansible role creation

  vllm:
    - vLLM typically supports latest CUDA (uses PyTorch backend)
    - Test installation in Week 1 (pip install vllm in virtualenv)
```

**Action Items:**
- [ ] **WEEK 1, DAY 1**: Verify PyTorch CUDA 12.4 wheel availability
- [ ] **WEEK 1, DAY 1**: Test TensorFlow CUDA 12.4 compatibility in VM
- [ ] **WEEK 1, DAY 2**: Create compatibility matrix document

#### RISK 3: PCIe 5.0 Stability
**Impact:** 🟡 **MEDIUM**
**Probability:** 40%

**Issue:**
- PCIe 5.0 is new technology (RTX 5090 uses PCIe 5.0 x16)
- Linux kernel PCIe subsystem may have Gen5 bugs
- WRX90 motherboard BIOS may require updates
- PCIe link training failures can cause GPU initialization errors

**Mitigation:**
```yaml
pcie_validation:
  bios_config:
    - Update WRX90 motherboard BIOS to latest version
    - Set PCIe to Gen5 explicitly (not Auto)
    - Enable Above 4G Decoding and Resizable BAR

  kernel_tuning:
    - Add pcie_aspm=off to GRUB_CMDLINE_LINUX (if stability issues)
    - Monitor dmesg for PCIe errors during boot
    - Use lspci -vvv to verify Gen5 link speed

  fallback:
    - Force PCIe Gen4 mode if Gen5 unstable (50% bandwidth reduction)
    - Test with single GPU first, then scale to 4
```

**Technical Specification:**
```bash
# Expected PCIe configuration validation
lspci -vvv | grep -A 20 "NVIDIA"
# Should show:
# LnkCap: Speed 32GT/s, Width x16   (PCIe Gen5)
# LnkSta: Speed 32GT/s, Width x16   (Current status)

# GRUB kernel parameters for PCIe stability
GRUB_CMDLINE_LINUX="pci=realloc pcie_aspm=off"
```

---

### 1.3 AI Runtime Layer Design

**Rating:** ✅ **VERY GOOD** (8/10)

**Architecture:**
```
┌──────────────────────────────────────────┐
│  User Workloads                          │
├──────────────────────────────────────────┤
│  PyTorch 2.x   TensorFlow 2.x   vLLM    │
├──────────────────────────────────────────┤
│  Python 3.10+ (system or venv)          │
├──────────────────────────────────────────┤
│  Docker Containers (optional)           │
├──────────────────────────────────────────┤
│  CUDA 12.4 + cuDNN 9.x                  │
└──────────────────────────────────────────┘
```

**Strengths:**
1. **All Three Major Frameworks** - PyTorch, TensorFlow, vLLM covers 95% of enterprise use cases
2. **System-Level Installation** - Frameworks installed globally (easier for demo box)
3. **Container Support** - Docker + NVIDIA Container Toolkit allows isolated workloads
4. **Multi-GPU Support** - PyTorch DDP and NCCL configured for 4-GPU training

**Gaps Identified:**

#### GAP 1: No Environment Isolation Strategy
**Issue:** Installing PyTorch, TensorFlow, and vLLM in the same Python environment can cause dependency conflicts.

**Example Conflict:**
```
PyTorch 2.2 requires numpy>=1.26.0,<2.0
TensorFlow 2.15 requires numpy>=1.23.5,<1.27
vLLM 0.3.0 requires transformers>=4.36.0
```

**Recommendation:**
```yaml
environment_strategy:
  option_a_system_install:
    - Install all frameworks in system Python (Epic 1A approach)
    - Test for conflicts in Week 2
    - Document known conflicts in demo-box-known-issues.md
    - Workaround: Use Docker containers for conflicting workloads

  option_b_conda:
    - Use Conda/Mamba for environment management
    - Create separate environments: pytorch-env, tensorflow-env, vllm-env
    - Add Miniconda to Ansible playbook
    - Complexity: Medium, Timeline: +1 day

  option_c_docker_only:
    - Pre-build Docker images: vault/pytorch:latest, vault/tensorflow:latest
    - No system Python packages (only Docker)
    - Complexity: Low, Enterprise-friendly
    - Timeline: +1 day
```

**Recommended Approach for Epic 1A:**
- **KEEP SYSTEM INSTALL** (simpler for demo box)
- **DOCUMENT CONFLICTS** in known issues
- **RECOMMEND DOCKER** for production workloads (defer to Epic 1B)
- **ADD TODO**: Create pre-built Docker images for each framework

#### GAP 2: No Model Download Strategy
**Issue:** Plan mentions downloading test models (opt-125m, Llama-2-7B) but no caching strategy.

**Problem:**
- Llama-2-7B is 13GB download
- Multiple re-downloads during testing waste time
- Air-gap deployment (Epic 1B) requires pre-cached models

**Recommendation:**
```yaml
model_cache_strategy:
  cache_location: /opt/vault-ai/models

  models_to_cache:
    - facebook/opt-125m          # 250MB (vLLM test)
    - meta-llama/Llama-2-7b-hf   # 13GB (vLLM validation)
    - gpt2                       # 500MB (PyTorch test)
    - bert-base-uncased          # 420MB (TensorFlow test)

  ansible_role:
    - Create /opt/vault-ai/models directory
    - Download models using huggingface-cli
    - Set HF_HOME=/opt/vault-ai/models environment variable
    - Add models to golden image (15GB total)

  timeline_impact: +2 hours (Task 1a.12 modification)
```

**Action Items:**
- [ ] Add `ansible/roles/model-cache` role
- [ ] Create `/opt/vault-ai/models` directory in base system
- [ ] Download test models during image build
- [ ] Document model cache location in setup guide

#### GAP 3: No NCCL Performance Validation
**Issue:** Plan tests PyTorch DDP but doesn't validate NCCL communication performance.

**Why This Matters:**
- NCCL is critical for multi-GPU training (handles GPU-to-GPU communication)
- PCIe topology affects NCCL performance (NVLink not available on RTX 5090)
- Misconfigured NCCL can reduce 4-GPU performance to <2x single GPU

**Recommendation:**
```yaml
nccl_validation:
  test_script: scripts/test-nccl-bandwidth.py

  tests:
    - NCCL all-reduce bandwidth (target: >50GB/s aggregate)
    - NCCL latency (target: <100μs)
    - GPU-to-GPU direct communication via PCIe
    - NVSwitch topology detection (should be N/A for RTX 5090)

  tools:
    - nccl-tests (NVIDIA official benchmark suite)
    - pytorch-test-nccl (PyTorch integration test)

  acceptance_criteria:
    - All-reduce bandwidth >50GB/s (4× RTX 5090)
    - No NCCL errors in dmesg
    - PyTorch DDP scaling efficiency >80%

  timeline_impact: +2 hours (add to Task 1a.14)
```

**Action Items:**
- [ ] Add NCCL bandwidth test to Task 1a.14
- [ ] Install nccl-tests package in Ansible
- [ ] Document NCCL performance baselines

---

### 1.4 Security Hardening Strategy

**Rating:** ✅ **APPROPRIATE for Epic 1A** (6/10 for demo, needs Epic 1B)

**Current Security Measures (Epic 1A):**
```yaml
security_controls:
  authentication:
    - SSH key-based authentication (password auth disabled) ✅
    - Root login disabled ✅
    - Non-root user (vaultadmin) with sudo ✅

  network:
    - UFW firewall enabled ✅
    - Default deny incoming ✅
    - SSH, HTTP, HTTPS allowed ✅

  intrusion_prevention:
    - fail2ban for SSH brute-force protection ✅

  updates:
    - Automatic security updates enabled ✅
```

**Deferred to Epic 1B (Correctly Scoped Out):**
```yaml
deferred_security:
  encryption:
    - Full disk encryption (LUKS) ❌ (Epic 1B)
    - Encrypted swap ❌ (Epic 1B)

  compliance:
    - CIS Level 1 benchmark ❌ (Epic 1B)
    - SELinux/AppArmor mandatory access control ❌ (Epic 1B)
    - Audit logging (auditd) ❌ (Epic 1B)

  hardening:
    - Kernel parameter tuning ❌ (Epic 1B)
    - Service minimization ❌ (Epic 1B)
    - File integrity monitoring (AIDE) ❌ (Epic 1B)
```

**Assessment:**
The security hardening is **appropriate for a demo box** but must be **clearly documented as INSUFFICIENT for production**. Epic 1A security is "good enough" for:
- Internal testing
- Customer demos (controlled environment)
- Proof-of-concept deployments

**NOT suitable for:**
- Production deployments
- Internet-facing systems
- Compliance-regulated environments (HIPAA, SOC2)

**Recommendation:**
```yaml
documentation_requirements:
  known_issues_doc:
    - Add "Security Limitations" section
    - Clearly state "Epic 1A is a DEMO BOX, not production-ready"
    - List all deferred security features
    - Provide Epic 1B timeline for production hardening

  setup_guide:
    - Add security warning banner at top
    - Recommend network isolation for demo environments
    - Document SSH key setup procedure
```

**Minor Security Gap:**
- **SSH Port 22** - Plan mentions "optional: 2222" but should **default to non-standard port** (reduces automated scanning)
- **No SSH Rate Limiting** - fail2ban is good, but add SSH rate limiting in sshd_config

**Recommended Addition:**
```yaml
# /etc/ssh/sshd_config improvements
Port 2222                          # Change from 22
MaxAuthTries 3                    # Limit auth attempts
LoginGraceTime 30                 # Timeout connection faster
ClientAliveInterval 300           # Keep-alive
ClientAliveCountMax 2             # Disconnect idle sessions
MaxSessions 2                     # Limit concurrent sessions
```

**Timeline Impact:** +30 minutes (Task 1a.5 modification)

---

### 1.5 Monitoring and Validation Approach

**Rating:** ✅ **GOOD** (7.5/10)

**Validation Coverage:**
```yaml
validation_tests:
  infrastructure:
    - GPU detection (4× RTX 5090) ✅
    - PCIe link speed validation ✅
    - Temperature monitoring ✅
    - Memory detection ✅

  frameworks:
    - PyTorch GPU access ✅
    - PyTorch DDP multi-GPU ✅
    - TensorFlow GPU access ✅
    - vLLM inference ✅

  stress_testing:
    - 24-hour thermal stress test ✅

  monitoring:
    - htop, iotop, nvtop ✅
    - nvidia-smi logging ✅
    - Basic monitoring script ✅
```

**Strengths:**
1. **Concrete Acceptance Criteria** - Each test has specific pass/fail criteria
2. **Multi-Layer Testing** - Infrastructure → Frameworks → Integration → Stress
3. **Thermal Validation** - 24-hour stress test will expose thermal throttling
4. **Automation-Friendly** - Scripts can be integrated into CI/CD

**Gaps:**

#### GAP 4: No Performance Regression Testing
**Issue:** No baseline performance metrics to detect regressions between builds.

**Recommendation:**
```yaml
performance_baselines:
  metrics_to_track:
    - PyTorch DDP throughput (samples/sec)
    - vLLM inference throughput (tokens/sec)
    - GPU utilization (%)
    - GPU memory bandwidth (GB/s)
    - NCCL all-reduce bandwidth (GB/s)

  implementation:
    - Save metrics to /opt/vault-ai/benchmarks/baseline.json
    - Compare each build to baseline (±10% tolerance)
    - Fail build if >10% performance regression
    - Add to Packer post-processor

  timeline_impact: +3 hours (add baseline collection script)
```

#### GAP 5: No Automated Test Suite
**Issue:** Validation scripts exist but no test harness to run them all.

**Recommendation:**
```yaml
test_harness:
  create_script: scripts/run-all-tests.sh

  test_execution_order:
    1. validate-gpus.sh           # Infrastructure (5 min)
    2. test-pytorch-basic.py      # Single GPU (2 min)
    3. test-pytorch-ddp.py        # Multi-GPU (10 min)
    4. test-tensorflow-basic.py   # Single GPU (2 min)
    5. test-vllm-inference.py     # Inference (15 min)
    6. test-nccl-bandwidth.py     # NCCL (5 min)

  total_runtime: ~40 minutes

  output:
    - JSON test results (/opt/vault-ai/test-results.json)
    - Human-readable summary (PASS/FAIL per test)
    - Exit code 0 if all pass, 1 if any fail

  timeline_impact: +2 hours (create test harness)
```

#### GAP 6: Insufficient Thermal Monitoring
**Issue:** 24-hour stress test planned but no detailed thermal data collection.

**Problem:**
- Plan mentions "monitor stress test" but no specifics
- GPU thermal throttling at 83°C (RTX 5090 likely similar)
- Need to track thermal throttling events, fan speeds, power consumption

**Recommendation:**
```yaml
thermal_monitoring_enhancement:
  metrics_to_log:
    - GPU temperature (°C) - every 5 seconds
    - GPU power draw (W) - every 5 seconds
    - GPU fan speed (%) - every 5 seconds
    - GPU clock speed (MHz) - every 5 seconds
    - Thermal throttling events (count)

  logging_script: scripts/thermal-stress-monitor.sh

  data_collection:
    - Log to CSV: /opt/vault-ai/stress-test-$(date).csv
    - Plot graphs: temperature over time, power over time
    - Generate report: thermal_stress_report.pdf

  alert_thresholds:
    - Temperature >80°C: WARNING
    - Temperature >85°C: CRITICAL
    - Thermal throttling: CRITICAL
    - Power >400W per GPU: WARNING

  timeline_impact: +2 hours (enhance stress test script)
```

**Detailed Thermal Test Script:**
```bash
#!/bin/bash
# scripts/thermal-stress-monitor.sh

DURATION=86400  # 24 hours in seconds
LOG_FILE="/opt/vault-ai/stress-test-$(date +%Y%m%d-%H%M%S).csv"

echo "timestamp,gpu_id,temp_c,power_w,fan_pct,clock_mhz,throttle" > "$LOG_FILE"

# Run stress test in background
python3 /opt/vault-ai/scripts/gpu-stress-test.py &
STRESS_PID=$!

# Monitor GPUs
for ((i=0; i<DURATION; i+=5)); do
  timestamp=$(date +%s)

  # Query all GPUs
  nvidia-smi --query-gpu=index,temperature.gpu,power.draw,fan.speed,clocks.current.graphics,clocks_throttle_reasons.active \
    --format=csv,noheader,nounits | while IFS=',' read -r gpu temp power fan clock throttle; do

    echo "$timestamp,$gpu,$temp,$power,$fan,$clock,$throttle" >> "$LOG_FILE"

    # Alert on critical conditions
    if [ "$temp" -gt 85 ]; then
      echo "CRITICAL: GPU $gpu temperature ${temp}°C"
      # Send alert (email, Slack, etc.)
    fi

    if [ "$throttle" != "0" ]; then
      echo "CRITICAL: GPU $gpu thermal throttling detected"
      # Send alert
    fi
  done

  sleep 5
done

# Kill stress test
kill $STRESS_PID

# Generate report
python3 /opt/vault-ai/scripts/generate-thermal-report.py "$LOG_FILE"
```

**Action Items:**
- [ ] Create thermal monitoring script (scripts/thermal-stress-monitor.sh)
- [ ] Create stress test workload (scripts/gpu-stress-test.py)
- [ ] Create report generator (scripts/generate-thermal-report.py)
- [ ] Add to Task 1a.17 (Validation phase)

---

## 2. Summary of Architectural Recommendations

### Critical (Must Address Before Epic 1A Starts):
1. ✅ **Verify RTX 5090 Driver Availability** - Research driver status, confirm NVIDIA repository has 550+ drivers
2. ✅ **Validate CUDA 12.4 Framework Compatibility** - Test PyTorch/TensorFlow wheels exist
3. ✅ **Procurement Backup GPU** - Have RTX 4090 available as fallback
4. ✅ **BIOS Configuration Guide** - Document WRX90 BIOS settings for PCIe 5.0

### High Priority (Add to Epic 1A):
5. ✅ **Model Cache Strategy** - Pre-download test models to golden image
6. ✅ **NCCL Bandwidth Test** - Add to multi-GPU validation
7. ✅ **Enhanced Thermal Monitoring** - Detailed 24-hour stress test logging
8. ✅ **Test Harness Creation** - Automated test suite (run-all-tests.sh)
9. ✅ **Performance Baseline Collection** - Save metrics for regression testing

### Medium Priority (Nice to Have):
10. ✅ **CI/CD Pipeline** - GitHub Actions for Packer/Ansible validation
11. ✅ **Image Versioning Strategy** - Semantic versioning and git tagging
12. ✅ **Build Caching** - Multi-stage Packer builds
13. ✅ **SSH Hardening** - Change default port to 2222, add rate limiting

### Low Priority (Defer to Epic 1B):
14. ⏸️ **Conda Environment Management** - Use Docker instead for isolation
15. ⏸️ **Pre-built Docker Images** - Create in Epic 1B
16. ⏸️ **Comprehensive CIS Compliance** - Epic 1B scope

---

## 3. Revised Task Additions

### NEW TASK: 1a.0 - Pre-Epic Hardware Validation
**Effort:** 4 hours
**MacBook:** ✅ Yes (research) + ❌ No (BIOS config)
**Dependencies:** GPU hardware available
**Timing:** BEFORE Week 1 starts

**Actions:**
- Research RTX 5090 Linux driver status (forums, release notes)
- Verify NVIDIA CUDA repository has driver 550+ packages
- Update WRX90 motherboard BIOS to latest version
- Configure BIOS for PCIe 5.0 (Above 4G Decoding, Resizable BAR)
- Boot system with Ubuntu 24.04 live USB, test GPU detection
- Document BIOS settings in `docs/bios-configuration.md`

**Acceptance Criteria:**
- [ ] NVIDIA driver 550+ confirmed available for Ubuntu 24.04
- [ ] WRX90 BIOS updated to latest version
- [ ] All 4× RTX 5090 GPUs visible in Ubuntu live USB (lspci)
- [ ] PCIe Gen5 link confirmed (lspci -vvv)
- [ ] BIOS configuration documented

---

### MODIFIED TASK: 1a.12 - Model Cache Addition
**Original Effort:** 3-4 hours
**Revised Effort:** 5-6 hours (+2 hours)

**Additional Actions:**
- Create `/opt/vault-ai/models` directory
- Download test models:
  - facebook/opt-125m (250MB)
  - meta-llama/Llama-2-7b-hf (13GB)
  - gpt2 (500MB)
  - bert-base-uncased (420MB)
- Set `HF_HOME=/opt/vault-ai/models` environment variable
- Document model cache location in setup guide

**Revised Acceptance Criteria:**
- [ ] All previous criteria from Task 1a.12
- [ ] Test models cached in `/opt/vault-ai/models`
- [ ] `HF_HOME` environment variable set globally
- [ ] vLLM uses cached models (no re-download)

---

### MODIFIED TASK: 1a.14 - NCCL Bandwidth Test Addition
**Original Effort:** 3-4 hours
**Revised Effort:** 5-6 hours (+2 hours)

**Additional Actions:**
- Install nccl-tests package
- Create NCCL bandwidth test: `scripts/test-nccl-bandwidth.sh`
- Run NCCL all-reduce benchmark (4× GPUs)
- Log NCCL performance metrics
- Validate NCCL bandwidth >50GB/s aggregate

**Revised Acceptance Criteria:**
- [ ] All previous criteria from Task 1a.14
- [ ] nccl-tests installed
- [ ] NCCL all-reduce bandwidth >50GB/s
- [ ] No NCCL errors in dmesg
- [ ] NCCL performance documented

---

### NEW TASK: 1a.18 - Automated Test Harness
**Effort:** 2-3 hours
**MacBook:** ✅ Yes (script creation) + ❌ No (execution)
**Dependencies:** All validation tasks (1a.13-1a.15)
**Timing:** Week 3, Day 2 (after individual tests validated)

**Actions:**
- Create `scripts/run-all-tests.sh` test harness
- Integrate all validation scripts (GPU, PyTorch, TensorFlow, vLLM, NCCL)
- Generate JSON test results (`/opt/vault-ai/test-results.json`)
- Create human-readable summary report
- Add exit code handling (0 = all pass, 1 = any fail)

**Acceptance Criteria:**
- [ ] Test harness executes all validation tests
- [ ] Total runtime <45 minutes
- [ ] JSON results file generated
- [ ] Summary report shows PASS/FAIL per test
- [ ] Exit code 0 if all tests pass

---

### NEW TASK: 1a.19 - Performance Baseline Collection
**Effort:** 3 hours
**MacBook:** ❌ No (GPU required)
**Dependencies:** Task 1a.18 (test harness)
**Timing:** Week 3, Day 3 (after tests pass)

**Actions:**
- Create `scripts/collect-baselines.sh` script
- Run all performance tests (PyTorch DDP, vLLM, NCCL)
- Save metrics to `/opt/vault-ai/benchmarks/baseline-v1.0.json`
- Document baseline values in `docs/performance-baselines.md`
- Add baseline comparison to future builds

**Acceptance Criteria:**
- [ ] Baseline metrics collected for all tests
- [ ] JSON file saved with version tag
- [ ] Documentation includes metric definitions
- [ ] Future builds can compare against baseline

---

## 4. Revised Timeline Impact

**Original Timeline:** 2-3 weeks, 60-90 hours
**Revised Timeline:** 2.5-3.5 weeks, 72-105 hours

**Additional Time Required:**
- Pre-Epic Hardware Validation: +4 hours
- Model Cache: +2 hours
- NCCL Testing: +2 hours
- Enhanced Thermal Monitoring: +2 hours
- Test Harness: +3 hours
- Baseline Collection: +3 hours
- Documentation Updates: +2 hours

**Total Additional Effort:** +18 hours (12-15 hours if parallel execution)

**Recommended Adjustment:**
- Keep 3-week timeline
- Increase effort estimate to 78-105 hours (was 60-90)
- Use Week 4 buffer for driver issues (not timeline extension)

---

## 5. Conclusion

The Epic 1A plan is **solid and executable**. The primary risk is RTX 5090 driver availability, which is **outside our control** but can be mitigated with proper pre-validation and fallback planning.

**Key Takeaways:**
1. **Architecture is sound** - Packer + Ansible is the right approach
2. **Risks are identified** - RTX 5090 drivers, thermal, CUDA compatibility
3. **Gaps are addressable** - Model caching, NCCL testing, test automation
4. **Timeline is realistic** - With adjustments, 3 weeks is achievable
5. **Security is appropriate** - Basic hardening suitable for demo box

**Go/No-Go Recommendation:**
✅ **GO** - Proceed with Epic 1A with the following conditions:
1. Complete Pre-Epic Hardware Validation (Task 1a.0) before Week 1
2. Confirm RTX 5090 driver availability in NVIDIA repository
3. Have backup RTX 4090 GPU available
4. Implement recommended task additions (model cache, NCCL test, test harness)
5. Document security limitations prominently

**Next Steps:**
1. Executive review of this architecture evaluation
2. Approval to proceed with Epic 1A
3. Schedule Pre-Epic Hardware Validation (Task 1a.0)
4. Confirm GPU hardware delivery for Week 2, Monday
5. Begin Week 1 Foundation tasks (MacBook-friendly)

---

**Evaluation Complete**
**Architect Sign-off:** Ready for Epic 1A execution with recommended improvements
