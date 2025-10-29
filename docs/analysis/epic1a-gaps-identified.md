# Epic 1A: Gaps Analysis

**Date:** 2025-10-29
**Analyst:** Vault AI Golden Image Architect
**Version:** 1.0
**Epic:** 1A - Demo Box Operation

---

## Executive Summary

This document identifies **14 gaps** in the Epic 1A implementation plan, categorized by severity and priority. While the plan is fundamentally sound, these gaps represent missing components, insufficient detail, or overlooked requirements that could impact deliverables.

**Gap Summary:**
- 🔴 **Critical Gaps:** 3 (must address before Epic 1A starts)
- 🟡 **High Priority Gaps:** 6 (add to Epic 1A tasks)
- 🟢 **Medium Priority Gaps:** 5 (nice to have, low impact)

**Overall Assessment:** The gaps are **addressable within the 3-week timeline** with minor adjustments (+12-18 hours total effort).

---

## Critical Gaps (Must Address)

### GAP-1: No Pre-Epic Hardware Validation
**Severity:** 🔴 **CRITICAL**
**Category:** Planning / Risk Management
**Impact:** Epic 1A may start without knowing if RTX 5090 drivers exist

#### Problem
The plan assumes Week 1 can proceed on MacBook while GPUs arrive for Week 2. However, there's no validation that RTX 5090 drivers are actually available for Ubuntu 24.04. If drivers don't exist, Week 2-3 tasks are impossible.

#### Current State
```yaml
week_1_plan:
  assumption: "GPUs will work in Week 2"
  risk: "No validation that drivers exist"
  consequences: "Could discover driver issue in Week 2, too late"
```

#### Required Solution
```yaml
new_task: "Task 1a.0 - Pre-Epic Hardware Validation"
timing: "BEFORE Week 1 starts (Week 0)"
effort: 4 hours
dependencies: "None (research-only)"

actions:
  - Research RTX 5090 Linux driver status (NVIDIA forums, release notes)
  - Verify NVIDIA CUDA repository has driver 550+ packages for Ubuntu 24.04
  - Test Ubuntu 24.04 live USB with GPU hardware (check lspci detection)
  - Update WRX90 BIOS to latest version
  - Configure BIOS for PCIe 5.0 (Above 4G Decoding, Resizable BAR)
  - Document BIOS settings in docs/bios-configuration.md

deliverables:
  - Pre-Epic validation report (GO/NO-GO decision)
  - BIOS configuration documentation
  - Driver availability confirmation
  - Fallback plan activation (if needed)
```

#### Timeline Impact
- **Add:** 4 hours (Week 0, before Epic 1A)
- **Benefit:** Prevents 2-week waste if drivers unavailable

**Owner:** DevOps Lead + Hardware Engineer
**Priority:** 🔴 **CRITICAL** - do this first

---

### GAP-2: No Model Caching Strategy
**Severity:** 🔴 **CRITICAL** (for air-gap Epic 1B)
**Category:** AI Runtime / Architecture
**Impact:** Epic 1B air-gap deployment will fail (models not cached)

#### Problem
Plan mentions downloading test models (opt-125m, Llama-2-7b) during vLLM validation, but doesn't cache them in the golden image. This creates two issues:

1. **Epic 1A:** Models re-downloaded every test run (wastes time)
2. **Epic 1B:** Air-gap deployment will fail (no internet to download models)

#### Current State
```yaml
task_1a12_vllm_installation:
  action: "Download facebook/opt-125m for testing"
  problem: "Model downloaded to ~/.cache/huggingface (ephemeral)"
  consequence: "Not included in golden image, air-gap deployment broken"
```

#### Required Solution
```yaml
model_cache_implementation:
  cache_location: /opt/vault-ai/models

  models_to_include:
    - facebook/opt-125m (250MB) - vLLM smoke test
    - meta-llama/Llama-2-7b-hf (13GB) - vLLM validation
    - gpt2 (500MB) - PyTorch test model
    - bert-base-uncased (420MB) - TensorFlow test model

  total_size: ~15GB (acceptable for 50GB image)

  ansible_implementation:
    role: ansible/roles/model-cache

    tasks:
      - name: Create model cache directory
        file:
          path: /opt/vault-ai/models
          state: directory
          owner: vaultadmin
          group: vaultadmin
          mode: '0755'

      - name: Set HuggingFace cache environment variable
        lineinfile:
          path: /etc/environment
          line: 'HF_HOME=/opt/vault-ai/models'
          create: yes

      - name: Download test models
        command: >
          huggingface-cli download {{ item }}
          --cache-dir /opt/vault-ai/models
        loop:
          - facebook/opt-125m
          - meta-llama/Llama-2-7b-hf
          - gpt2
          - bert-base-uncased

      - name: Set ownership
        file:
          path: /opt/vault-ai/models
          owner: vaultadmin
          group: vaultadmin
          recurse: yes
```

#### Timeline Impact
- **Add:** 2 hours to Task 1a.12 (model download automation)
- **Benefit:** Epic 1B air-gap deployment works without modification

**Owner:** ML Engineer
**Priority:** 🔴 **CRITICAL** - blocks Epic 1B

---

### GAP-3: No NCCL Performance Validation
**Severity:** 🟡 **HIGH** (becomes critical if scaling fails)
**Category:** Validation / Performance
**Impact:** Multi-GPU training may be slow, no way to detect

#### Problem
Plan tests PyTorch DDP (Task 1a.14) but doesn't validate NCCL communication performance. NCCL is critical for multi-GPU training - misconfigured NCCL can reduce 4-GPU performance to <2x single GPU.

#### Why This Matters
```yaml
nccl_importance:
  what_is_nccl: "NVIDIA Collective Communication Library"
  role: "Handles GPU-to-GPU communication (gradients, parameters)"
  performance_impact: "Can make or break multi-GPU scaling"

  example_bad_config:
    issue: "PCIe topology not optimized"
    symptom: "4-GPU training only 2.1x faster than single GPU"
    expected: "4-GPU training should be 3.2x+ faster (80% scaling efficiency)"

  failure_modes:
    - GPUs communicating via CPU (slow)
    - PCIe lanes not optimized
    - NCCL using wrong backend (shared memory vs PCIe)
    - Network topology misconfiguration
```

#### Current State
```yaml
task_1a14_pytorch_ddp:
  test: "ResNet-50 DDP training"
  metrics: "Throughput, scaling efficiency"
  missing: "No NCCL bandwidth test, no communication profiling"
```

#### Required Solution
```yaml
nccl_validation_addition:
  test_tool: nccl-tests (NVIDIA official benchmark)

  installation:
    - Install nccl-tests package
    - Compile from source if needed (https://github.com/NVIDIA/nccl-tests)

  tests_to_run:
    - all_reduce_perf (most important for DDP)
    - all_gather_perf
    - broadcast_perf
    - reduce_scatter_perf

  test_script: scripts/test-nccl-bandwidth.sh

  acceptance_criteria:
    all_reduce_bandwidth: ">50 GB/s (aggregate, 4× RTX 5090)"
    latency: "<100 μs"
    no_errors: "dmesg | grep -i nccl should be clean"

  example_output:
    #                                                       out-of-place                       in-place
    #       size         count      type   redop     time   algbw   busbw  error     time   algbw   busbw  error
    #        (B)    (elements)                       (us)  (GB/s)  (GB/s)            (us)  (GB/s)  (GB/s)
    8589934592      2147483648     float     sum    1234   56.78   85.17  0e+00    1199   58.34   87.51  0e+00

  timeline_impact: +2 hours (Task 1a.14)
```

**Owner:** ML Engineer / DevOps Lead
**Priority:** 🟡 **HIGH** - add to Task 1a.14

---

## High Priority Gaps

### GAP-4: No Automated Test Harness
**Severity:** 🟡 **HIGH**
**Category:** Validation / Automation
**Impact:** Manual test execution error-prone, time-consuming

#### Problem
Plan creates individual validation scripts (validate-gpus.sh, test-pytorch-ddp.py, etc.) but no unified test harness to run all tests automatically. This means:

- Manual test execution (human error risk)
- No standardized output format
- Can't integrate with CI/CD
- No pass/fail summary

#### Required Solution
```yaml
test_harness_creation:
  script: scripts/run-all-tests.sh

  test_execution_order:
    - validate-gpus.sh (infrastructure - 5 min)
    - test-pytorch-basic.py (single GPU - 2 min)
    - test-pytorch-ddp.py (multi-GPU - 10 min)
    - test-tensorflow-basic.py (single GPU - 2 min)
    - test-vllm-inference.py (inference - 15 min)
    - test-nccl-bandwidth.py (NCCL - 5 min)

  total_runtime: ~40 minutes

  output_format:
    - JSON results: /opt/vault-ai/test-results.json
    - Human-readable summary (PASS/FAIL per test)
    - Exit code 0 if all pass, 1 if any fail

  example_implementation:
    #!/bin/bash
    set -e
    RESULTS_FILE="/opt/vault-ai/test-results.json"
    echo '{"tests": []}' > "$RESULTS_FILE"

    run_test() {
      local test_name="$1"
      local test_script="$2"

      echo "Running $test_name..."
      if "$test_script"; then
        echo "✅ PASS: $test_name"
        jq ".tests += [{\"name\": \"$test_name\", \"status\": \"PASS\"}]" "$RESULTS_FILE" > tmp.$$ && mv tmp.$$ "$RESULTS_FILE"
      else
        echo "❌ FAIL: $test_name"
        jq ".tests += [{\"name\": \"$test_name\", \"status\": \"FAIL\"}]" "$RESULTS_FILE" > tmp.$$ && mv tmp.$$ "$RESULTS_FILE"
        exit 1
      fi
    }

    run_test "GPU Detection" "/opt/vault-ai/scripts/validate-gpus.sh"
    run_test "PyTorch Basic" "python3 /opt/vault-ai/scripts/test-pytorch-basic.py"
    # ... more tests ...

    echo "All tests passed!"

  timeline_impact: +3 hours (new Task 1a.18)
```

**Owner:** DevOps Lead
**Priority:** 🟡 **HIGH** - enables CI/CD

---

### GAP-5: No Performance Baseline Collection
**Severity:** 🟡 **HIGH**
**Category:** Validation / Regression Testing
**Impact:** Can't detect performance regressions between builds

#### Problem
Plan runs performance tests (PyTorch DDP, vLLM) but doesn't save baseline metrics. Without baselines, can't detect if future changes degrade performance.

#### Example Scenario
```yaml
scenario:
  week_3: "PyTorch DDP achieves 120 samples/sec (4-GPU)"
  week_4: "Minor driver update"
  week_5: "PyTorch DDP now achieves 85 samples/sec (30% regression!)"
  problem: "No baseline saved, regression undetected"
```

#### Required Solution
```yaml
baseline_collection:
  metrics_to_save:
    - PyTorch DDP throughput (samples/sec)
    - vLLM inference throughput (tokens/sec)
    - NCCL all-reduce bandwidth (GB/s)
    - GPU utilization (%)
    - GPU memory usage (GB)
    - Build time (minutes)

  storage_format: /opt/vault-ai/benchmarks/baseline-v1.0.json

  example_baseline_file:
    {
      "version": "1.0.0",
      "date": "2025-10-29",
      "hardware": {
        "gpu": "4× RTX 5090",
        "cpu": "AMD Threadripper PRO 7975WX",
        "ram": "256GB DDR5"
      },
      "benchmarks": {
        "pytorch_ddp_resnet50": {
          "throughput": 120.5,
          "unit": "samples/sec",
          "scaling_efficiency": 0.82
        },
        "vllm_llama2_7b": {
          "throughput": 12.3,
          "unit": "tokens/sec",
          "gpu_memory": 28.4
        },
        "nccl_allreduce": {
          "bandwidth": 56.7,
          "unit": "GB/s",
          "latency_us": 89
        }
      }
    }

  comparison_script: scripts/compare-to-baseline.sh

  timeline_impact: +3 hours (new Task 1a.19)
```

**Owner:** ML Engineer
**Priority:** 🟡 **HIGH** - prevents regressions

---

### GAP-6: Insufficient Thermal Monitoring
**Severity:** 🟡 **HIGH**
**Category:** Validation / Hardware
**Impact:** Thermal issues not detected until too late

#### Problem
Plan mentions "24-hour stress test" and "monitor temperatures" but doesn't specify HOW to monitor or WHAT to log. Given 2400W GPU power draw, thermal monitoring is critical.

#### Required Enhancement
```yaml
thermal_monitoring_script: scripts/thermal-stress-monitor.sh

metrics_to_log:
  - GPU temperature (°C) - every 5 seconds
  - GPU power draw (W) - every 5 seconds
  - GPU fan speed (%) - every 5 seconds
  - GPU clock speed (MHz) - every 5 seconds
  - Thermal throttling events (count)
  - Room ambient temperature (if sensor available)

log_format: CSV (/opt/vault-ai/stress-test-YYYYMMDD.csv)

alert_thresholds:
  temperature_warning: 80°C
  temperature_critical: 85°C
  thermal_throttle: "Any throttling event"
  power_warning: 400W per GPU

visualization:
  - Generate graphs (temperature over time, power over time)
  - Create report: thermal_stress_report.pdf
  - Include in setup guide as validation example

timeline_impact: +2 hours (enhance Task 1a.17)
```

**Owner:** Hardware Engineer
**Priority:** 🟡 **HIGH** - thermal is high risk

---

### GAP-7: No CI/CD Integration
**Severity:** 🟡 **HIGH**
**Category:** Automation / DevOps
**Impact:** Manual build validation, no automated testing

#### Problem
Plan uses Packer + Ansible but doesn't integrate with GitHub Actions or GitLab CI. Every build requires manual validation, and bugs aren't caught early.

#### Required Solution
```yaml
github_actions_workflow: .github/workflows/validate-golden-image.yml

workflow_triggers:
  - push: [main, develop]
  - pull_request: [main, develop]

jobs:
  validate-packer:
    runs-on: ubuntu-latest
    steps:
      - Checkout code
      - Install Packer
      - Run packer validate ubuntu-24.04-demo-box.pkr.hcl
      - Run packer fmt -check (check formatting)

  lint-ansible:
    runs-on: ubuntu-latest
    steps:
      - Checkout code
      - Install ansible-lint
      - Run ansible-lint ansible/playbooks/site.yml

  test-ansible-syntax:
    runs-on: ubuntu-latest
    steps:
      - Checkout code
      - Install Ansible
      - Run ansible-playbook --syntax-check ansible/playbooks/site.yml

  # Full build test (commented out - requires GPU hardware)
  # build-image:
  #   runs-on: self-hosted-gpu
  #   steps:
  #     - Checkout code
  #     - Run packer build ubuntu-24.04-demo-box.pkr.hcl
  #     - Run scripts/run-all-tests.sh

timeline_impact: +4 hours (setup CI/CD)
```

**Owner:** DevOps Lead
**Priority:** 🟡 **HIGH** - improves quality

---

### GAP-8: No Image Versioning Strategy
**Severity:** 🟡 **HIGH**
**Category:** Release Management
**Impact:** Can't track which image version deployed to customer

#### Problem
Plan mentions "vault-cube-demo-box-v1.0.qcow2" but no strategy for:
- Semantic versioning (when to increment major vs minor)
- Git tagging aligned with releases
- Changelog generation
- Rollback to previous versions

#### Required Solution
```yaml
versioning_strategy:
  semantic_versioning:
    format: "vMAJOR.MINOR.PATCH-BUILD"
    examples:
      - v1.0.0-demo (Epic 1A deliverable)
      - v1.1.0-demo (Epic 1A with bug fixes)
      - v2.0.0-production (Epic 1B deliverable)

  version_increments:
    major: "Breaking changes (e.g., Ubuntu 24.04 → 26.04)"
    minor: "New features (e.g., add Kubernetes support)"
    patch: "Bug fixes, security updates"
    build: "Automated builds (CI/CD)"

  git_tagging:
    - Tag releases: git tag -a v1.0.0-demo -m "Epic 1A Demo Box"
    - Push tags: git push origin v1.0.0-demo

  changelog:
    - Auto-generate from git commits
    - Use conventional commits (feat:, fix:, docs:)
    - Tool: git-cliff or conventional-changelog

  image_naming:
    - vault-cube-v1.0.0-demo-box.qcow2
    - vault-cube-v2.0.0-production.qcow2

  metadata_file: /etc/vault-ai/image-version.json
    {
      "version": "1.0.0-demo",
      "build_date": "2025-10-29",
      "git_commit": "abc123",
      "epic": "1A - Demo Box Operation"
    }

timeline_impact: +2 hours (setup versioning)
```

**Owner:** DevOps Lead
**Priority:** 🟡 **HIGH** - essential for releases

---

### GAP-9: No Rollback Mechanism
**Severity:** 🟡 **HIGH**
**Category:** Risk Management
**Impact:** If Week 3 build breaks, can't revert to Week 2

#### Problem
Packer builds a single monolithic image. If a change in Week 3 breaks the image, there's no way to revert to a known-good Week 2 build.

#### Required Solution
```yaml
rollback_strategy:
  multi_stage_builds:
    - Stage 1: Base OS + drivers (vault-cube-v1.0.0-base.qcow2)
    - Stage 2: Base + frameworks (vault-cube-v1.0.0-frameworks.qcow2)
    - Stage 3: Full image (vault-cube-v1.0.0-demo.qcow2)

  packer_implementation:
    - Use Packer's qemu builder with backing files
    - Stage 2 builds on top of Stage 1 (doesn't rebuild from scratch)
    - Stage 3 builds on top of Stage 2

  benefits:
    - Faster iteration (only rebuild changed stages)
    - Can rollback to any stage
    - Easier debugging (isolate which stage broke)

  timeline_impact: +4 hours (refactor Packer template)
```

**Owner:** DevOps Lead
**Priority:** 🟡 **HIGH** - reduces risk

---

## Medium Priority Gaps (Nice to Have)

### GAP-10: No Environment Isolation (PyTorch vs TensorFlow)
**Severity:** 🟢 **MEDIUM**
**Category:** AI Runtime
**Impact:** Potential dependency conflicts

**Solution:** Accept system-level install for Epic 1A, document conflicts, recommend Docker for Epic 1B.

**Timeline Impact:** None (defer to Epic 1B)

---

### GAP-11: No Build Time Optimization
**Severity:** 🟢 **MEDIUM**
**Category:** Performance
**Impact:** Slow iterative builds (30+ minutes per build)

**Solution:** Implement APT caching (apt-cacher-ng), PyPI mirror, multi-stage Packer builds.

**Timeline Impact:** +3 hours (optional optimization)

---

### GAP-12: No Security Scanning
**Severity:** 🟢 **MEDIUM** (Epic 1A), 🔴 **CRITICAL** (Epic 1B)
**Category:** Security
**Impact:** Unknown vulnerabilities in golden image

**Solution:** Add Trivy or Grype scanning to CI/CD, generate SBOM (Software Bill of Materials).

**Timeline Impact:** +2 hours (defer to Epic 1B)

---

### GAP-13: No Documentation Generation Automation
**Severity:** 🟢 **MEDIUM**
**Category:** Documentation
**Impact:** Manual documentation updates error-prone

**Solution:** Auto-generate docs from Ansible playbooks, extract version info automatically.

**Timeline Impact:** +2 hours (optional)

---

### GAP-14: No Customer Feedback Loop
**Severity:** 🟢 **MEDIUM**
**Category:** Product
**Impact:** Demo box may not meet customer needs

**Solution:** Schedule customer demo in Week 3, Friday. Collect feedback for Epic 1B.

**Timeline Impact:** None (schedule meeting)

---

## Gap Resolution Timeline

### Immediate (Week 0 - Before Epic 1A)
- ✅ **GAP-1:** Pre-Epic Hardware Validation (+4 hours)

### Week 1 Additions
- ✅ **GAP-4:** CI/CD Integration (+4 hours)
- ✅ **GAP-8:** Image Versioning Strategy (+2 hours)

### Week 2 Additions
- ✅ **GAP-2:** Model Caching (+2 hours to Task 1a.12)
- ✅ **GAP-3:** NCCL Validation (+2 hours to Task 1a.14)

### Week 3 Additions
- ✅ **GAP-4:** Automated Test Harness (+3 hours, new Task 1a.18)
- ✅ **GAP-5:** Baseline Collection (+3 hours, new Task 1a.19)
- ✅ **GAP-6:** Thermal Monitoring (+2 hours, enhance Task 1a.17)

### Optional (Buffer Week 4)
- ⏸️ **GAP-9:** Rollback Mechanism (+4 hours)
- ⏸️ **GAP-11:** Build Optimization (+3 hours)

**Total Additional Effort:** 18 hours (critical) + 11 hours (high priority) = **29 hours**

**Revised Epic 1A Estimate:** 60-90 hours → **78-119 hours**

---

## Recommendations

### Must Do (Critical Gaps)
1. **Add Task 1a.0** - Pre-Epic Hardware Validation (Week 0)
2. **Enhance Task 1a.12** - Add model caching
3. **Enhance Task 1a.14** - Add NCCL validation

### Should Do (High Priority Gaps)
4. **Add Task 1a.18** - Automated test harness
5. **Add Task 1a.19** - Baseline collection
6. **Enhance Task 1a.17** - Thermal monitoring
7. **Setup CI/CD** - GitHub Actions workflows
8. **Define Versioning** - Semantic versioning strategy

### Nice to Have (Medium Priority Gaps)
9. **Multi-stage Packer builds** - Rollback capability
10. **Build caching** - Faster iteration
11. **Security scanning** - Vulnerability detection

**Conclusion:** Gaps are **manageable and addressable**. Critical gaps add ~18 hours (still within 3-week timeline with buffer).

---

**Document Owner:** Vault AI Architect
**Status:** Complete
**Next Steps:** Review gaps with team, prioritize for Epic 1A execution
