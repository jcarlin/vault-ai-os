# Epic 1A Technical Dependencies - Executive Summary
**Date:** 2025-10-29
**Research Status:** COMPLETE
**Overall Risk Level:** 🟡 MEDIUM-HIGH (Feasible with proper planning)

---

## 🎯 Critical Success Factors

Epic 1A (4× RTX 5090 GPU Golden Image) is **TECHNICALLY FEASIBLE** but requires:

1. **Manual BIOS Configuration** (cannot be automated)
2. **CUDA 12.8 + PyTorch 2.7+** (CUDA 12.4 insufficient)
3. **Custom Liquid Cooling** (~$5-7k investment)
4. **Kernel 6.12+ Upgrade** (Ubuntu 24.04 default insufficient)
5. **Open Kernel Modules ONLY** (proprietary drivers will fail)

---

## 🚨 Critical Blockers Identified

### 1. RTX 5090 Driver Compatibility (🔴 HIGH PRIORITY)

**Issue:** Ubuntu 24.04 LTS does NOT support RTX 5090 out-of-box

**Requirements:**
- NVIDIA Driver 570.86.16+ (MUST use open kernel modules)
- Kernel 6.12+ or 6.13+ (default 6.8 insufficient)
- PCIe Gen 4.0 BIOS setting (Gen 5.0 has 15-25% failure rate)

**Impact:** Golden image deployment will FAIL without manual driver installation

**Mitigation:**
- Pre-bake kernel 6.13+ into Packer image
- Use `nvidia-driver-570-server-open` (NOT proprietary driver)
- Document manual BIOS configuration (PCIe Gen 4.0)
- Implement extended GPU detection timeouts

**Automation Status:** ✅ Driver installation automatable, ❌ BIOS config requires manual setup

---

### 2. CUDA Toolkit Compatibility (🔴 HIGH PRIORITY)

**Issue:** RTX 5090 (Blackwell, SM 12.0) requires CUDA 12.8 - CUDA 12.4 will NOT work

**Error with CUDA 12.4:**
```
RuntimeError: sm_120 is not supported
CUDA error: no kernel image available
```

**Framework Compatibility:**

| Framework | CUDA Version | RTX 5090 Support | Status |
|-----------|--------------|------------------|--------|
| **PyTorch 2.7+** | 12.8 | ✅ Full support | RECOMMENDED |
| **PyTorch 2.4-2.6** | 12.4 | ❌ NO (sm_120 error) | AVOID |
| **TensorFlow 2.x** | 12.3 (official) | ⚠️ Limited | NOT RECOMMENDED |
| **vLLM** | 12.8 | ⚠️ Single GPU only | Multi-GPU BROKEN |

**Decision:** Standardize on **PyTorch 2.7+ with CUDA 12.8** (bundled in NGC containers)

**Mitigation:**
- Use NVIDIA NGC PyTorch container: `nvcr.io/nvidia/pytorch:25.02-py3`
- Avoid manual CUDA installation (use containerized approach)
- Document Flash Attention 2 requirement (FA3 not yet compatible)

**Automation Status:** ✅ Fully automatable via Docker/Ansible

---

### 3. Multi-GPU Framework Issues (🟡 MEDIUM PRIORITY)

**Issue:** vLLM tensor parallelism has active NCCL P2P bugs with RTX 5090

**Affected Frameworks:**
- vLLM tensor parallelism (TP=2 or TP=4): ❌ BROKEN (GitHub issue #14628)
- TensorRT-LLM multi-GPU: ⚠️ Similar NCCL P2P issues
- PyTorch DDP: ✅ WORKING (tested and stable)

**Status:** Active bugs as of March 2025, community investigating

**Mitigation:**
- **Primary:** Use PyTorch DistributedDataParallel (DDP) - proven stable
- **Fallback:** Single-GPU vLLM instances with load balancing
- **Monitor:** Subscribe to vLLM GitHub issues for bug fixes
- **Avoid:** vLLM tensor parallelism until P2P issues resolved

**Performance Impact:**
- PyTorch DDP scaling: 3.4-3.6× speedup with 4 GPUs (85-90% efficiency)
- vLLM workaround: Multiple single-GPU instances (less efficient memory usage)

**Automation Status:** ✅ PyTorch DDP automatable, ⚠️ vLLM requires workarounds

---

### 4. Thermal Management (🔴 CRITICAL)

**Issue:** 4× RTX 5090 generates 2.5-3.2kW heat - standard cooling INSUFFICIENT

**Heat Output:**
- 4× RTX 5090: 2,300W (rated) to 3,200W (peak)
- Threadripper PRO: 350W
- **Total System:** 2.9-3.8kW = 9,900-13,000 BTU/hr

**Air Cooling Verdict:** ❌ **WILL NOT WORK** (thermal throttling guaranteed)

**Required Solution:** Custom dual-loop liquid cooling

**Components Needed:**
- CPU Loop: 360mm radiator (Threadripper PRO)
- GPU Loop: 2× 480mm radiators (4× RTX 5090)
- 11× high-performance fans (Noctua NF-A12x25)
- Chassis: Corsair Obsidian 1000D ($600)
- Water cooling: $3,000-4,500
- Room cooling: 15,000 BTU AC unit ($800-1,200)

**Total Cooling Cost:** $5,000-7,000

**Alternative:** 5U rackmount with datacenter-grade cooling (extremely loud)

**Mitigation:**
- Budget $5-7k for custom liquid cooling
- Plan room HVAC upgrade (15,000 BTU minimum)
- Implement thermal monitoring with emergency shutdown
- Conduct 24-hour thermal soak test post-deployment

**Automation Status:** ❌ Cannot automate (physical hardware required)

---

### 5. Packer/Ansible Automation Limitations (🟡 MEDIUM PRIORITY)

**Issue:** BIOS configuration cannot be automated without IPMI/BMC

**Cannot be Automated:**
- PCIe Gen 4.0 setting (CRITICAL for stability)
- Above 4G Decoding (required for multi-GPU)
- Resizable BAR configuration
- BIOS updates

**Can be Automated:**
- Kernel upgrade to 6.13+
- NVIDIA driver 570-server-open installation
- CUDA toolkit via containers
- GPU validation and testing

**Mitigation:**
- Document manual BIOS configuration checklist
- Create Ansible playbook to verify settings post-boot (via dmidecode/lspci)
- Implement extended timeouts for multi-GPU detection (45+ min builds)
- Use cloud-init for post-deployment driver installation

**Build Time:** 45-60 minutes (includes kernel upgrade + reboot)

**Automation Status:** ⚠️ Partial (BIOS requires manual configuration)

---

## 📊 Compatibility Matrix Summary

### Hardware Compatibility
| Component | Minimum Spec | Recommended | Status |
|-----------|--------------|-------------|--------|
| GPU | RTX 5090 | RTX 5090 | ✅ Supported |
| CPU | Threadripper PRO | Threadripper PRO 9995WX | ✅ Supported |
| Motherboard | WRX90 | ASUS Pro WS WRX90E-SAGE SE | ✅ Supported |
| RAM | 256GB DDR5 | 512GB DDR5 | ✅ Supported |
| Cooling | Custom Liquid | Dual-loop custom | ⚠️ Required |
| PCIe Mode | Gen 4.0 | Gen 4.0 | ⚠️ Manual BIOS |

---

### Software Compatibility
| Component | Minimum | Recommended | Status |
|-----------|---------|-------------|--------|
| OS | Ubuntu 24.04 LTS | Ubuntu 24.04.2 LTS | ⚠️ Requires manual driver |
| Kernel | 6.8.0 | 6.12+ / 6.13+ | ⚠️ Upgrade required |
| NVIDIA Driver | 570.86.16-open | 575.64-open | ✅ Automatable |
| CUDA | 12.8 | 12.8 | ✅ Containerized |
| PyTorch | 2.7.0 | 2.7.0+ | ✅ NGC container |
| TensorFlow | N/A | N/A | ❌ Not recommended |
| vLLM | N/A | N/A | ⚠️ Single GPU only |

---

## 🎯 Recommended Technology Stack

### Primary Development Environment
```yaml
Container: nvcr.io/nvidia/pytorch:25.02-py3
Framework: PyTorch 2.7+
CUDA: 12.8 (bundled)
cuDNN: 9.1.0+ (bundled)
Multi-GPU: DistributedDataParallel (DDP)
Alternative: Single-GPU vLLM instances + load balancer
```

### System Configuration
```yaml
OS: Ubuntu 24.04.2 LTS
Kernel: 6.13+ (upgraded from default 6.8)
Driver: nvidia-driver-570-server-open (or newer)
PCIe: Gen 4.0 mode (BIOS setting)
Cooling: Dual-loop custom liquid cooling
Room: 15,000 BTU dedicated AC
```

---

## 📋 Pre-Deployment Checklist

### Manual Configuration (Before Packer Build)
- [ ] Update motherboard BIOS to latest version
- [ ] Set PCIe speed to Gen 4.0 (NOT Auto, NOT Gen 5)
- [ ] Enable Above 4G Decoding
- [ ] Enable Resizable BAR
- [ ] Disable Secure Boot (if driver issues occur)
- [ ] Document BIOS settings in deployment runbook

### Automated via Packer/Ansible
- [ ] Install Ubuntu 24.04.2 LTS with autoinstall
- [ ] Upgrade kernel to 6.13+
- [ ] Install NVIDIA driver 570-server-open
- [ ] Disable Nouveau driver
- [ ] Pull PyTorch NGC container
- [ ] Validate all 4 GPUs detected
- [ ] Run thermal stress test
- [ ] Configure thermal monitoring

### Physical Infrastructure
- [ ] Procure custom liquid cooling components ($3-4.5k)
- [ ] Install dual-loop cooling system
- [ ] Configure 11× case fans
- [ ] Install room AC unit (15,000 BTU)
- [ ] Verify adequate power (2800W+ PSU)
- [ ] Implement thermal emergency shutdown

---

## 🚧 Known Risks and Mitigation

### 🔴 Critical Risks

**Risk 1: PCIe 5.0 Stability Issues**
- **Impact:** 15-25% of systems experience black screens
- **Probability:** HIGH if BIOS not configured
- **Mitigation:** Set PCIe Gen 4.0 in BIOS (1-4% performance loss acceptable)

**Risk 2: Thermal Throttling**
- **Impact:** GPU performance degradation, potential hardware damage
- **Probability:** CERTAIN without custom liquid cooling
- **Mitigation:** $5-7k investment in dual-loop cooling system

**Risk 3: vLLM Multi-GPU Failure**
- **Impact:** Cannot use tensor parallelism for large models
- **Probability:** CONFIRMED (active bug)
- **Mitigation:** Use PyTorch DDP or single-GPU vLLM instances

---

### 🟡 Medium Risks

**Risk 4: BIOS Configuration Errors**
- **Impact:** GPUs not detected or unstable
- **Probability:** MEDIUM (human error)
- **Mitigation:** Detailed runbook, post-boot validation scripts

**Risk 5: Kernel/Driver Compatibility**
- **Impact:** Build failure, extended troubleshooting
- **Probability:** MEDIUM if using wrong packages
- **Mitigation:** Automated validation in Ansible playbooks

**Risk 6: Build Time Overruns**
- **Impact:** Packer builds timeout
- **Probability:** MEDIUM for multi-GPU detection
- **Mitigation:** Extended timeouts (45-60 min), retry logic

---

## 💰 Cost Analysis

### Hardware Costs (Excluding GPUs/CPU)
```yaml
Cooling System:
  - Custom liquid cooling: $3,000-4,500
  - Corsair Obsidian 1000D: $600
  - Case fans (11×): $300-400
  - Room AC (15,000 BTU): $800-1,200
  Subtotal: $4,700-6,700

Power:
  - 2800W PSU: $800-1,200
  - 240V circuit installation: $500-1,000
  Subtotal: $1,300-2,200

Motherboard:
  - ASUS Pro WS WRX90E-SAGE SE: $1,200

Total (excluding GPUs/CPU): $7,200-10,100
```

### Alternative: Rackmount Solution
```yaml
5U Rackmount Chassis: $1,500-2,500
Rackmount PSU (2800W): $800-1,200
Rack (42U): $500-1,000
Datacenter space (monthly): $500-2,000/mo
Total: $3,300-6,700 + ongoing costs
```

---

## ⏱️ Timeline Estimates

### Phase 1: Planning and Procurement (2-3 weeks)
- Week 1: Finalize specifications, order components
- Week 2-3: Component delivery, BIOS configuration documentation

### Phase 2: Packer/Ansible Development (1-2 weeks)
- Week 1: Develop Packer template with kernel upgrade
- Week 2: Create Ansible roles for driver installation and validation

### Phase 3: Physical Build (1-2 weeks)
- Week 1: Assemble cooling system (DIY or professional)
- Week 2: Leak test, initial system boot

### Phase 4: Software Deployment (1 week)
- Packer golden image build (45-60 min per iteration)
- Multi-GPU validation
- Thermal soak testing (24-48 hours)

### Phase 5: Validation and Tuning (1 week)
- PyTorch DDP benchmarking
- vLLM single-GPU testing
- Thermal optimization
- Documentation

**Total Timeline:** 6-9 weeks from start to production-ready

---

## 🎯 Go/No-Go Recommendation

### GO - Epic 1A is FEASIBLE with conditions:

**Requirements Met:**
✅ RTX 5090 drivers available (570-open+)
✅ CUDA 12.8 support in PyTorch 2.7+
✅ PyTorch DDP proven stable for multi-GPU
✅ Automation possible with Packer/Ansible (with manual BIOS step)
✅ Thermal solutions available (custom liquid cooling)

**Critical Dependencies:**
⚠️ Budget approved for $5-7k cooling system
⚠️ Manual BIOS configuration accepted (cannot be automated)
⚠️ vLLM tensor parallelism deferred until bug fixes
⚠️ 6-9 week timeline acceptable
⚠️ Room HVAC upgrade planned

**Showstoppers (if any):**
❌ Budget for cooling denied → DEFER until resolved
❌ Cannot accept manual BIOS config → Requires IPMI/BMC motherboard
❌ Need vLLM tensor parallelism immediately → DEFER until NCCL P2P fixed

---

## 📚 Deliverables

All research findings documented in:
- `/docs/epic1a/research/rtx5090-drivers.md` - Driver compatibility and installation
- `/docs/epic1a/research/cuda-compatibility.md` - CUDA toolkit and framework matrix
- `/docs/epic1a/research/multi-gpu-frameworks.md` - PyTorch DDP, vLLM, TensorFlow
- `/docs/epic1a/research/automation-best-practices.md` - Packer/Ansible patterns
- `/docs/epic1a/research/thermal-management.md` - Cooling requirements and monitoring

Findings stored in coordination memory:
- `epic1a/research/rtx5090-drivers`
- `epic1a/research/cuda-compatibility`
- `epic1a/research/frameworks`
- `epic1a/research/automation`
- `epic1a/research/thermal`

---

## 🔄 Next Steps

### Immediate (Week 1):
1. Obtain stakeholder approval for $5-7k cooling budget
2. Finalize hardware procurement (cooling components, chassis)
3. Create BIOS configuration runbook (manual steps)
4. Begin Packer template development (kernel 6.13 upgrade)

### Short-term (Weeks 2-4):
5. Develop Ansible roles for NVIDIA driver 570-open
6. Create validation playbooks (GPU detection, CUDA version, thermal)
7. Assemble custom liquid cooling system
8. Configure room HVAC (15,000 BTU AC)

### Medium-term (Weeks 5-9):
9. Run Packer golden image build with validation
10. Deploy to test system with single GPU first
11. Scale to 4-GPU configuration
12. Conduct 24-hour thermal soak test
13. Benchmark PyTorch DDP multi-GPU training
14. Document deployment runbook

---

## 📞 Escalation Points

**If encountered during implementation:**

1. **PCIe Gen 5.0 black screens persist with Gen 4.0 setting**
   → Escalate to BIOS vendor, try driver 580+ when available

2. **vLLM multi-GPU required for project**
   → Escalate to vLLM GitHub maintainers, monitor NCCL P2P bug fixes

3. **Thermal throttling with custom liquid cooling**
   → Increase radiator capacity, verify fan curves, check ambient temp

4. **Packer builds timeout beyond 60 minutes**
   → Increase timeout to 90 min, check GPU detection timing

5. **Budget constraints for cooling**
   → Reduce to 2× RTX 5090 (more feasible with hybrid cooling)

---

**Research completed:** 2025-10-29
**Researcher:** Technical Research Specialist
**Status:** ✅ READY FOR STAKEHOLDER REVIEW
