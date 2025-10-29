# Week 0: RTX 5090 Technical Research & Validation

**Epic:** 1A Demo Box Operation (4× RTX 5090 GPU Golden Image)
**Status:** COMPLETE
**Date Completed:** 2025-10-29
**Decision Status:** PENDING STAKEHOLDER REVIEW

---

## Overview

Week 0 research validates the technical feasibility of building a 4× RTX 5090 GPU golden image for the Vault Cube AI workstation. This directory contains all research findings, validation reports, and decision matrices required to proceed with Epic 1A.

**Key Finding:** Project is **technically feasible** but requires significant modifications including custom liquid cooling ($7k), CUDA 12.8 (not 12.4), and manual BIOS configuration.

---

## Executive Summary

### Critical Findings

1. **CUDA 12.8 Required** - CUDA 12.4 will NOT work with RTX 5090 (Blackwell architecture)
2. **Custom Liquid Cooling Mandatory** - Air cooling insufficient for 2.5-3.2kW heat output
3. **Kernel Upgrade Required** - Ubuntu 24.04 default kernel (6.8) insufficient, need 6.12+
4. **Open Driver Modules Only** - Proprietary NVIDIA drivers will fail, must use `-open` variant
5. **vLLM Multi-GPU Broken** - Active bug, use PyTorch DDP for multi-GPU instead
6. **Manual BIOS Configuration** - PCIe Gen 4.0 setting cannot be automated

---

## Deliverables

### 1. Validation Report
**File:** `validation-report.md`
**Purpose:** Comprehensive technical validation of all Epic 1A requirements

**Contents:**
- Driver compatibility research (RTX 5090 on Ubuntu 24.04)
- CUDA compatibility matrix (12.8 requirement)
- Multi-GPU framework validation (PyTorch DDP, vLLM, TensorFlow)
- Thermal management requirements (custom liquid cooling)
- Automation feasibility (Packer/Ansible)
- Consolidated findings and recommendations

**Key Sections:**
- Section 1: Driver Compatibility (kernel 6.13+, open modules, PCIe Gen 4.0)
- Section 2: CUDA Compatibility (CUDA 12.8, PyTorch 2.7+, NGC containers)
- Section 3: Multi-GPU Frameworks (PyTorch DDP ✅, vLLM tensor parallelism ❌)
- Section 4: Thermal Management (custom liquid cooling $7k, 15,000 BTU AC)
- Section 5: Automation Feasibility (85% automatable, BIOS manual)
- Section 6: Consolidated Findings (Epic 1A updates required)

---

### 2. GO/NO-GO Decision Matrix
**File:** `go-no-go-decision.md`
**Purpose:** Structured decision framework for stakeholder approval

**Contents:**
- GO/NO-GO criteria with status (5 GO, 2 CONDITIONAL, 1 PENDING)
- Detailed assessment of each criterion
- Risk assessment (Critical, High, Medium)
- Fallback options (2× RTX 5090, RTX 4090, defer)
- Stakeholder sign-off checklist

**Key Criteria:**
1. ✅ RTX 5090 drivers available
2. ✅ CUDA 12.8 support in frameworks
3. ✅ Multi-GPU capability achievable
4. 🟡 Automation feasible (85%, BIOS manual)
5. 🟡 Thermal solution available (+$7k budget)
6. ⚠️ Budget pending approval
7. ✅ Timeline acceptable (3-4 weeks)
8. ✅ Hardware procurement on schedule

**Decision:** Recommend **GO** pending $7k cooling budget approval.

---

### 3. Week 0 Overview (This Document)
**File:** `README.md`
**Purpose:** Quick navigation and executive summary for stakeholders

---

## Research Documents (Referenced)

All detailed research is located in `/docs/epic1a/research/`:

1. **rtx5090-drivers.md** - Driver compatibility and installation
   - NVIDIA Driver 570+ (open kernel modules)
   - Kernel 6.12+ or 6.13+ requirement
   - PCIe Gen 4.0 BIOS configuration
   - Multi-GPU installation order

2. **cuda-compatibility.md** - CUDA toolkit and framework matrix
   - CUDA 12.8 requirement (12.4 insufficient)
   - PyTorch 2.7+ support
   - TensorFlow limitations (CUDA 12.3 official)
   - NGC container recommendations

3. **multi-gpu-frameworks.md** - PyTorch DDP, vLLM, TensorFlow
   - PyTorch DDP: 85-90% scaling efficiency ✅
   - vLLM tensor parallelism: Active bug ❌
   - TensorRT-LLM: Similar NCCL P2P issues ⚠️
   - Recommended strategy: PyTorch DDP primary

4. **thermal-management.md** - Cooling requirements and monitoring
   - Heat output: 2.9-3.8kW (9,900-13,000 BTU/hr)
   - Custom liquid cooling: Dual-loop, $3-4.5k
   - Room AC: 15,000 BTU required ($800-2k)
   - Thermal monitoring and emergency shutdown

5. **automation-best-practices.md** - Packer/Ansible patterns
   - 85% automatable (kernel, driver, validation)
   - 15% manual (BIOS configuration)
   - Build time: 45-60 minutes (kernel upgrade + reboot)
   - Extended timeouts for multi-GPU detection

6. **EXECUTIVE_SUMMARY.md** - High-level findings
   - GO/NO-GO recommendation
   - Critical dependencies
   - Budget requirements
   - Timeline estimates

---

## Quick Navigation

### For Stakeholders (Decision Makers)

**Start Here:**
1. Read `go-no-go-decision.md` (Decision matrix with sign-off checklist)
2. Review `validation-report.md` Section 6 (Consolidated findings)
3. Review `validation-report.md` Section 7 (Recommendations)
4. Sign off on decision matrix

**Key Questions to Answer:**
- Is $7,000 budget approved for cooling infrastructure?
- Is manual BIOS configuration acceptable?
- Is PyTorch DDP + single-GPU vLLM acceptable for demo?
- Is 3-4 week timeline acceptable?

---

### For Engineers (Implementation Team)

**Start Here:**
1. Read `validation-report.md` in full (all technical findings)
2. Review `/docs/epic1a/research/` for detailed specifications
3. Check Epic 1A updates required (Section 6 of validation report)

**Key Technical Details:**
- CUDA 12.8 requirement (not 12.4)
- Kernel 6.13+ upgrade required
- NVIDIA driver 570-server-open (not proprietary)
- PyTorch DDP as primary multi-GPU framework
- Custom liquid cooling specifications

---

### For Procurement (Hardware Team)

**Immediate Actions (If GO Decision):**
1. Order custom liquid cooling components
   - CPU Loop: 360mm radiator, EK-D5 pump, CPU block
   - GPU Loop: 2× 480mm radiators, 2× EK-D5 pumps, 4× GPU blocks
   - Fittings, tubing, coolant (see thermal-management.md)
2. Procure Corsair Obsidian 1000D chassis
3. Order 11× Noctua NF-A12x25 PWM fans
4. Purchase 15,000 BTU portable AC unit

**Budget Estimate:** $5,700-9,100 (recommend $7,000)

**Lead Times:**
- Cooling components: 3-5 days
- Chassis: 1-2 weeks
- AC unit: 3-7 days

---

## Risk Summary

### Critical Risks (🔴)

| Risk | Impact | Mitigation | Status |
|------|--------|------------|--------|
| **Thermal throttling** | System unusable | Custom liquid cooling ($7k) | ⚠️ Pending budget |
| **CUDA 12.4 used** | Frameworks fail | Document CUDA 12.8 requirement | ✅ Documented |
| **PCIe 5.0 instability** | Black screen on boot | Set BIOS to Gen 4.0 (manual) | ✅ Runbook ready |
| **Budget not approved** | Cannot proceed | Present fallback options | ⚠️ Pending decision |

### High Risks (🟡)

| Risk | Impact | Mitigation | Status |
|------|--------|------------|--------|
| **vLLM multi-GPU broken** | Cannot demo tensor parallelism | Use PyTorch DDP instead | ✅ Workaround ready |
| **BIOS config errors** | GPU detection failure | Detailed runbook, validation | ✅ Documented |
| **Room overheating** | Thermal shutdown | 15,000 BTU AC unit | ⚠️ Pending budget |

---

## Budget Impact

### Original Budget
- Hardware only (GPUs, CPU, motherboard, RAM)

### Additional Requirements (Week 0 Findings)

| Item | Cost | Status |
|------|------|--------|
| Custom liquid cooling components | $3,000-4,500 | ⚠️ Pending approval |
| Corsair Obsidian 1000D chassis | $600 | ⚠️ Pending approval |
| Case fans (11× Noctua) | $300-500 | ⚠️ Pending approval |
| Professional installation (optional) | $1,000-1,500 | ⚠️ Optional |
| Room AC unit (15,000 BTU) | $800-2,000 | ⚠️ Pending approval |
| **Total** | **$5,700-9,100** | ⚠️ Pending approval |

**Recommended Budget:** $7,000 (mid-range estimate)

---

## Timeline Impact

### Original Epic 1A Timeline
- 2-3 weeks

### Updated Timeline (Week 0 Findings)
- **Week 0:** Research and validation (COMPLETE)
- **Week 1:** Foundation + cooling procurement
- **Week 2:** Cooling installation + AI runtime (GPU hardware required)
- **Week 3:** Validation + documentation
- **Week 4:** Buffer (cooling assembly, thermal tuning)

**Total:** 3-4 weeks (1 week added for cooling assembly)

---

## Changes Required to Epic 1A

### Critical Updates

1. **Task 1a.8 - NVIDIA Drivers + CUDA**
   - Change CUDA to **12.8** (not 12.4+)
   - Specify **open kernel modules** (nvidia-driver-570-server-open)
   - Add kernel upgrade to 6.13+ before driver installation

2. **Task 1a.10 - PyTorch Installation**
   - Use NGC container (nvcr.io/nvidia/pytorch:25.02-py3)
   - Remove manual CUDA installation (bundled in container)

3. **Task 1a.11 - TensorFlow Installation**
   - Mark as **OPTIONAL** or defer to Epic 1B
   - Reason: CUDA 12.3 limitation, limited RTX 5090 optimization

4. **Task 1a.15 - vLLM Inference Validation**
   - Change to single GPU only (not multi-GPU tensor parallelism)
   - Add note about active vLLM bug (GitHub #14628)

5. **New Task: Thermal Management Setup**
   - Custom liquid cooling installation
   - Thermal monitoring systemd service
   - Emergency shutdown script

6. **New Pre-Deployment: Manual BIOS Configuration**
   - BIOS configuration runbook
   - PCIe Gen 4.0 requirement
   - ReBAR, Above 4G Decoding settings

### Performance Expectations

| Metric | Original | Updated | Notes |
|--------|----------|---------|-------|
| Packer Build Time | <30 min | 45-60 min | Kernel upgrade + reboot |
| Multi-GPU Framework | vLLM | PyTorch DDP | vLLM tensor parallelism broken |
| Scaling Efficiency | >80% | 85-90% | PyTorch DDP exceeds target |
| GPU Temps (Load) | Unknown | 65-75°C | With custom liquid cooling |

---

## Fallback Options

### Option A: Reduce to 2× RTX 5090
- Deploy 2× RTX 5090 instead of 4×
- Cooling: $3,000-4,000 (hybrid AIO + custom CPU loop)
- **Cost Savings:** ~$3,000-4,000
- **Trade-off:** Lower multi-GPU scaling demo

### Option B: Use RTX 4090 Instead
- Deploy 4× RTX 4090 instead of RTX 5090
- CUDA 12.4 support (no CUDA 12.8 requirement)
- **Cost Savings:** ~$3,000-4,000 (lower GPU cost + cooling)
- **Trade-off:** Not latest generation hardware

### Option C: Defer Epic 1A
- Pivot to Epic 1B preparation
- Procure cooling first, then restart
- **Timeline Impact:** +2-3 weeks

---

## Next Steps

### Immediate (This Week)

**For Stakeholders:**
1. Review GO/NO-GO decision matrix
2. Approve/reject $7,000 cooling budget
3. Sign off on manual BIOS configuration
4. Approve Epic 1A updates (CUDA 12.8, PyTorch DDP primary, etc.)

**For Engineers (If GO Decision):**
1. Update Epic 1A with Week 0 findings
2. Create manual BIOS configuration runbook
3. Develop Packer template with kernel 6.13 upgrade
4. Create Ansible roles for driver installation

**For Procurement (If GO Decision):**
1. Order custom liquid cooling components (3-5 day lead time)
2. Procure Corsair Obsidian 1000D chassis
3. Purchase 15,000 BTU portable AC unit

---

### Week 1 (If GO Decision)

1. Execute Epic 1A tasks 1a.1-1a.7 (MacBook-friendly)
2. Receive and inspect cooling components
3. Prepare chassis for cooling installation
4. Create Packer template with kernel upgrade
5. Develop Ansible driver installation role

---

## Document Metadata

**Created:** 2025-10-29
**Status:** COMPLETE
**Next Review:** After stakeholder decision (GO/NO-GO)

**Contact for Questions:**
- Technical Questions: Engineering Lead
- Budget Questions: CTO / Finance
- Timeline Questions: Product Lead

---

## Appendix: Quick Reference

### Key Specifications

**Hardware:**
- GPUs: 4× NVIDIA RTX 5090 (32GB GDDR7 each)
- CPU: AMD Threadripper PRO 9995WX
- RAM: 512GB DDR5 ECC
- Cooling: Dual-loop custom liquid cooling

**Software:**
- OS: Ubuntu 24.04.2 LTS
- Kernel: 6.12+ or 6.13+
- Driver: NVIDIA 570.86.16+ (open kernel modules)
- CUDA: 12.8 (bundled in NGC container)
- Framework: PyTorch 2.7+ (CUDA 12.8 build)

**BIOS Configuration (Manual):**
- PCIe Generation: **Gen 4.0** (NOT Auto, NOT Gen 5)
- Above 4G Decoding: **Enabled**
- Resizable BAR: **Enabled**
- CSM: **Disabled**
- Secure Boot: **Disabled** (if driver issues)

---

### Key Contacts

**Week 0 Research Team:**
- Driver Compatibility: Research Specialist
- CUDA Compatibility: Framework Engineer
- Multi-GPU Frameworks: ML Engineer
- Thermal Management: Hardware Engineer
- Automation: DevOps Engineer

**Stakeholder Approval:**
- Budget: CTO / Finance
- Technical: Engineering Lead
- Timeline: Product Lead

---

**README Status:** COMPLETE
**Document Version:** 1.0
**Last Updated:** 2025-10-29
